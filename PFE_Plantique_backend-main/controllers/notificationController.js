const Notification = require("../models/Notification");
const User = require("../models/User");
exports.createNotification = async ({
  userId,
  type = "system",
  title,
  message,
  fromUserId,
  postId,
  blogId,
  reminderId,
  plantSlug,
  plantName,
}) => {
  if (!userId) return null;

  const notif = await Notification.create({
    user: userId,
    type,
    title,
    message,
    fromUser: fromUserId,
    post: postId,
    blog: blogId,
    reminder: reminderId,
    plantSlug,
    plantName,
  });

  return notif;
};

/**
 * Helper : créer la même notif pour plusieurs users (ex: nouveau blog)
 */
exports.createNotificationForMany = async ({
  userIds,
  type = "blog",
  title,
  message,
  blogId,
  postId,
}) => {
  if (!userIds || userIds.length === 0) return;

  const docs = userIds.map((uid) => ({
    user: uid,
    type,
    title,
    message,
    blog: blogId,
    post: postId,
  }));

  const notifs = await Notification.insertMany(docs);

  return notifs;
};

/**
 * GET /api/notifications
 */
exports.listMyNotifications = async (req, res) => {
  try {
    const userId = req.user._id;

    const notifs = await Notification.find({ user: userId })
      .sort({ createdAt: -1 })
      .populate("fromUser", "username picture")
      .lean();

    return res.status(200).json({
      ok: true,
      data: notifs,
    });
  } catch (err) {
    console.error("listMyNotifications error:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while fetching notifications",
    });
  }
};

/**
 * PATCH /api/notifications/:id/read
 */
exports.markAsRead = async (req, res) => {
  try {
    const userId = req.user._id;
    const { id } = req.params;

    const notif = await Notification.findOneAndUpdate(
      { _id: id, user: userId },
      { read: true },
      { new: true },
    );

    if (!notif) {
      return res
        .status(404)
        .json({ ok: false, error: "Notification not found" });
    }

    return res.status(200).json({ ok: true, data: notif });
  } catch (err) {
    console.error("markAsRead error:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while updating notification",
    });
  }
};

/**
 * PATCH /api/notifications/read-all
 */
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user._id;

    await Notification.updateMany(
      { user: userId, read: false },
      { read: true },
    );

    return res.status(200).json({
      ok: true,
      message: "All notifications marked as read",
    });
  } catch (err) {
    console.error("markAllAsRead error:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while updating notifications",
    });
  }
};

/**
 * DELETE /api/notifications/:id
 */
exports.deleteNotification = async (req, res) => {
  try {
    const userId = req.user._id;
    const { id } = req.params;

    const deleted = await Notification.findOneAndDelete({
      _id: id,
      user: userId,
    });

    if (!deleted) {
      return res.status(404).json({
        ok: false,
        error: "Notification not found",
      });
    }

    return res.status(200).json({
      ok: true,
      message: "Notification deleted",
    });
  } catch (err) {
    console.error("deleteNotification error:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while deleting notification",
    });
  }
};
