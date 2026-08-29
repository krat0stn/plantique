const Event = require("../models/Event");
const cloudinary = require("cloudinary").v2;

const uploadImage = (buffer) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: "events", resource_type: "image" },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });

// Helper: delete past events
const cleanupPastEvents = async () => {
  try {
    await Event.deleteMany({ endDate: { $lt: new Date() } });
  } catch (_) {}
};

// GET /api/admin/events
exports.list = async (_req, res) => {
  try {
    await cleanupPastEvents();
    const events = await Event.find().sort({ endDate: -1 });
    res.json({ data: events });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/admin/events/:id
exports.getById = async (req, res) => {
  try {
    const event = await Event.findById(req.params.id);
    if (!event) return res.status(404).json({ error: "Event not found" });
    res.json({ data: event });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/admin/events
exports.create = async (req, res) => {
  try {
    const { title, description, location, price, startDate, endDate } = req.body;

    if (!title || !startDate || !endDate) {
      return res.status(400).json({ error: "title, startDate, and endDate are required" });
    }

    let imageUrl, imagePublicId;
    if (req.file) {
      const result = await uploadImage(req.file.buffer);
      imageUrl = result.secure_url;
      imagePublicId = result.public_id;
    }

    const event = await Event.create({
      title,
      description: description || "",
      location: location || "",
      price: Number(price) || 0,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      imageUrl,
      imagePublicId,
    });

    res.status(201).json({ data: event });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/admin/events/:id
exports.update = async (req, res) => {
  try {
    const event = await Event.findById(req.params.id);
    if (!event) return res.status(404).json({ error: "Event not found" });

    const { title, description, location, price, startDate, endDate } = req.body;

    if (title       !== undefined) event.title       = title;
    if (description !== undefined) event.description = description;
    if (location    !== undefined) event.location    = location;
    if (price       !== undefined) event.price       = Number(price);
    if (startDate   !== undefined) event.startDate   = new Date(startDate);
    if (endDate     !== undefined) event.endDate     = new Date(endDate);

    if (req.file) {
      if (event.imagePublicId) {
        await cloudinary.uploader.destroy(event.imagePublicId).catch(() => {});
      }
      const result = await uploadImage(req.file.buffer);
      event.imageUrl = result.secure_url;
      event.imagePublicId = result.public_id;
    }

    await event.save();
    res.json({ data: event });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// DELETE /api/admin/events/:id
exports.remove = async (req, res) => {
  try {
    const event = await Event.findByIdAndDelete(req.params.id);
    if (!event) return res.status(404).json({ error: "Event not found" });

    if (event.imagePublicId) {
      await cloudinary.uploader.destroy(event.imagePublicId).catch(() => {});
    }

    res.json({ message: "Event deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
