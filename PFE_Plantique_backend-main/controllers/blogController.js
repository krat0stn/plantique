const Blog = require("../models/Blog");
const User = require("../models/User");
const { notifyBlogNew } = require("../utils/realtime");
const { createNotificationForMany } = require("./notificationController");
const { cloudinary } = require("../config/cloudinary");

exports.listPublic = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.min(
      Math.max(parseInt(req.query.limit || "10", 10), 1),
      100,
    );
    const skip = (page - 1) * limit;
    const { q } = req.query;

    const filter = {};
    if (q && q.trim()) filter.$text = { $search: q.trim() };

    const [items, total] = await Promise.all([
      Blog.find(filter, "title excerpt imageUrl author createdAt")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("author", "username picture"),
      Blog.countDocuments(filter),
    ]);

    return res.status(200).json({
      successmessage: "Blogs récupérés (public)",
      data: items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.getPublicById = async (req, res) => {
  try {
    const found = await Blog.findById(req.params.id).populate(
      "author",
      "username picture",
    );
    if (!found)
      return res.status(404).json({ errormessage: "Blog introuvable" });

    return res
      .status(200)
      .json({ successmessage: "Blog récupéré", data: found });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.listAdmin = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.min(
      Math.max(parseInt(req.query.limit || "10", 10), 1),
      100,
    );
    const skip = (page - 1) * limit;
    const { q } = req.query;

    const filter = {};
    if (q && q.trim()) filter.$text = { $search: q.trim() };

    const [items, total] = await Promise.all([
      Blog.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("author", "username picture"),
      Blog.countDocuments(filter),
    ]);

    return res.status(200).json({
      successmessage: "Blogs récupérés (admin)",
      data: items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.create = async (req, res) => {
  try {
    const { title, content, excerpt } = req.body;
    if (!title || !content) {
      return res
        .status(400)
        .json({ errormessage: "title et content sont requis" });
    }
    if (!req.file) {
      return res
        .status(400)
        .json({ errormessage: "Image requise. Envoyez un fichier 'image'." });
    }

    const created = await Blog.create({
      title: title.trim(),
      content: content.trim(),
      excerpt: excerpt?.trim(),
      imageUrl: req.file.path,
      imagePublicId: req.file.filename,
      author: req.user?._id || req.user?.id || null,
    });

    notifyBlogNew?.(created);

    try {
      const clients = await User.find({ role: "User" }).select("_id");
      const userIds = clients.map((u) => u._id);
      if (userIds.length > 0) {
        await createNotificationForMany({
          userIds,
          type: "blog",
          title: "New blog article",
          message: created.title,
          blogId: created._id,
        });
      }
    } catch (notifyErr) {
      console.error("Error creating blog notifications:", notifyErr.message);
    }

    return res.status(201).json({ successmessage: "Blog créé", data: created });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.update = async (req, res) => {
  try {
    const { title, content, excerpt } = req.body;
    const blog = await Blog.findById(req.params.id);
    if (!blog)
      return res.status(404).json({ errormessage: "Blog introuvable" });

    const update = {};
    if (title !== undefined) update.title = title.trim();
    if (content !== undefined) update.content = content.trim();
    if (excerpt !== undefined) update.excerpt = excerpt.trim();

    if (req.file) {
      if (blog.imagePublicId) {
        try {
          await cloudinary.uploader.destroy(blog.imagePublicId);
        } catch {}
      }
      update.imageUrl = req.file.path;
      update.imagePublicId = req.file.filename;
    }

    const updated = await Blog.findByIdAndUpdate(req.params.id, update, {
      new: true,
    });
    return res
      .status(200)
      .json({ successmessage: "Blog mis à jour", data: updated });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.remove = async (req, res) => {
  try {
    const blog = await Blog.findById(req.params.id);
    if (!blog)
      return res.status(404).json({ errormessage: "Blog introuvable" });

    if (blog.imagePublicId) {
      try {
        await cloudinary.uploader.destroy(blog.imagePublicId);
      } catch {}
    }
    await blog.deleteOne();

    return res
      .status(200)
      .json({ successmessage: "Blog supprimé", data: blog });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.removeImage = async (req, res) => {
  try {
    const blog = await Blog.findById(req.params.id);
    if (!blog)
      return res.status(404).json({ errormessage: "Blog introuvable" });

    if (blog.imagePublicId) {
      try {
        await cloudinary.uploader.destroy(blog.imagePublicId);
      } catch {}
    }

    blog.imageUrl = null;
    blog.imagePublicId = null;
    await blog.save();

    return res
      .status(200)
      .json({ successmessage: "Image supprimée", data: blog });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};
