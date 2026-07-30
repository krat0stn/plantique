// controllers/reminderController.js
const Reminder = require("../models/Reminder");
const PlantCare = require("../models/Plant");
const { createNotification } = require("../controllers/notificationController");

function buildNextDate(dateOnly, timeOfDay) {
  const base = new Date(dateOnly);
  if (!timeOfDay) return base;

  const [h, m] = timeOfDay.split(":").map((x) => parseInt(x, 10));
  if (!isNaN(h)) base.setHours(h);
  if (!isNaN(m)) base.setMinutes(m);
  base.setSeconds(0);
  base.setMilliseconds(0);
  return base;
}

// POST /api/reminders
exports.createReminder = async (req, res) => {
  try {
    const userId = req.user && (req.user._id || req.user.id);
    if (!userId) {
      return res.status(401).json({ ok: false, error: "Unauthorized" });
    }

    const {
      plantSlug,
      plantName,
      type,
      intervalDays,
      startDate,
      timeOfDay,
      notes,
    } = req.body;

    if (!plantSlug || !type) {
      return res.status(400).json({
        ok: false,
        error: "plantSlug and type are required",
      });
    }

    const interval =
      intervalDays && Number(intervalDays) > 0 ? Number(intervalDays) : 7;

    const baseDate = startDate ? new Date(startDate) : new Date();
    const nextDate = buildNextDate(baseDate, timeOfDay || "09:00");

    const reminder = await Reminder.create({
      user: userId,
      plantSlug: String(plantSlug).trim().toLowerCase(),
      plantName,
      type,
      intervalDays: interval,
      nextDate,
      timeOfDay: timeOfDay || "09:00",
      notes,
      source: "manual",
    });

    // 🔔 Notification "meta" pour dire que le reminder est bien créé
    try {
      await createNotification({
        userId,
        type: "reminder",
        title: `Reminder created - ${plantName || plantSlug}`,
        message: `We will remind you for ${type} every ${interval} day(s) at ${reminder.timeOfDay}.`,
        reminderId: reminder._id,
      });
    } catch (notifyErr) {
      console.error("Error creating reminder notification:", notifyErr.message);
    }

    return res.status(201).json({ ok: true, data: reminder });
  } catch (err) {
    console.error("Error creating reminder:", err);
    return res.status(500).json({
      ok: false,
      error: "Server error while creating reminder",
    });
  }
};

// GET /api/reminders
exports.listMyReminders = async (req, res) => {
  try {
    const userId = req.user && (req.user._id || req.user.id);
    if (!userId) {
      return res.status(401).json({ ok: false, error: "Unauthorized" });
    }

    const reminders = await Reminder.find({ user: userId })
      .sort({ nextDate: 1 })
      .lean();

    return res.json({ ok: true, data: reminders });
  } catch (err) {
    console.error("Error fetching reminders:", err);
    return res.status(500).json({
      ok: false,
      error: "Server error while fetching reminders",
    });
  }
};

// PATCH /api/reminders/:id
exports.updateReminder = async (req, res) => {
  try {
    const userId = req.user && (req.user._id || req.user.id);
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({ ok: false, error: "Unauthorized" });
    }

    const allowedFields = [
      "intervalDays",
      "nextDate",
      "timeOfDay",
      "notes",
      "active",
    ];
    const update = {};
    for (const key of allowedFields) {
      if (req.body[key] !== undefined) {
        update[key] = req.body[key];
      }
    }

    if (update.nextDate && update.timeOfDay) {
      update.nextDate = buildNextDate(update.nextDate, update.timeOfDay);
    }

    const reminder = await Reminder.findOneAndUpdate(
      { _id: id, user: userId },
      update,
      { new: true }
    );

    if (!reminder) {
      return res.status(404).json({ ok: false, error: "Reminder not found" });
    }

    return res.json({ ok: true, data: reminder });
  } catch (err) {
    console.error("Error updating reminder:", err);
    return res.status(500).json({
      ok: false,
      error: "Server error while updating reminder",
    });
  }
};

// DELETE /api/reminders/:id
exports.deleteReminder = async (req, res) => {
  try {
    const userId = req.user && (req.user._id || req.user.id);
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({ ok: false, error: "Unauthorized" });
    }

    const deleted = await Reminder.findOneAndDelete({
      _id: id,
      user: userId,
    });

    if (!deleted) {
      return res.status(404).json({ ok: false, error: "Reminder not found" });
    }

    return res.json({ ok: true, message: "Reminder deleted" });
  } catch (err) {
    console.error("Error deleting reminder:", err);
    return res.status(500).json({
      ok: false,
      error: "Server error while deleting reminder",
    });
  }
};
