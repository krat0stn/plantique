// controllers/posteController.js
const Poste = require("../models/Poste");
const Like = require("../models/Like");
const Save = require("../models/Save");
const Comment = require("../models/Comment");
const User = require("../models/User");
const { notifyPostNew } = require("../utils/realtime");
const {
  createNotification,
  createNotificationForMany,
} = require("../controllers/notificationController");

// GET /api/postes
exports.getAllPostesAdmin = async (req, res) => {
  try {
    const posts = await Poste.find()
      .sort({ createdAt: -1 })
      .populate('userId', 'username email picture');
    
    res.json({ ok: true, data: posts });
  } catch (err) {
    console.error("Error fetching admin posts:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
};

// GET /api/postes/:id
exports.getPosteById = async (req, res) => {
  const { id } = req.params;
  try {
    const found = await Poste.findById(id);
    if (!found)
      return res.status(404).json({ errormessage: "Poste introuvable" });
    return res.status(200).json({
      successmessage: "Poste récupéré avec succès",
      data: found,
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur " + error.message });
  }
};

// POST /api/postes
exports.create = async (req, res) => {
  try {
    // Id utilisateur sécurisé via token, fallback sur body si besoin
    const userId = req.user?.id || req.user?._id || req.body.userId;
    const { content, status } = req.body;

    if (!userId || !content || !content.trim()) {
      return res.status(400).json({
        errormessage: "userId et content sont obligatoires",
      });
    }

    const picturePath = req.file
      ? req.file.path
      : req.body.picture?.toString() || null;

    const newPoste = await Poste.create({
      userId,
      content: content.trim(),
      picture: picturePath,
      ...(status ? { status } : {}),
    });

    // 🔔 Realtime
    notifyPostNew?.(newPoste);

    // 🔔 Notification à l'auteur
    try {
      await createNotification({
        userId,
        type: "post",
        title: "Post created",
        message: "Your post has been created and is pending review.",
        postId: newPoste._id,
      });
    } catch (notifyErr) {
      console.error(
        "Error creating post author notification:",
        notifyErr.message
      );
    }

    // 🔔 Notification à tous les admins (nouveau post à modérer)
    try {
      const admins = await User.find({ role: "Admin" }).select("_id");
      const adminIds = admins.map((a) => a._id);

      if (adminIds.length > 0) {
        await createNotificationForMany({
          userIds: adminIds,
          type: "post",
          title: "New post to review",
          message: "A new community post has been created and needs review.",
          postId: newPoste._id,
        });
      }
    } catch (notifyErr) {
      console.error(
        "Error creating admin post notifications:",
        notifyErr.message
      );
    }

    return res.status(201).json({
      successmessage: "Poste créé avec succès",
      data: newPoste,
    });
  } catch (error) {
    return res.status(500).json({
      errormessage: "Erreur lors de la création du poste",
      error: error.message,
    });
  }
};

// PUT /api/postes/:id
exports.updateSinglePoste = async (req, res) => {
  const { id } = req.params;
  const { content } = req.body;

  try {
    const updateData = {};

    if (content !== undefined) {
      if (!content.trim()) {
        return res
          .status(400)
          .json({ errormessage: "content ne peut pas être vide" });
      }
      updateData.content = content.trim();
    }

    if (req.file) {
      updateData.picture = req.file.path;
    } else if (req.body.picture !== undefined) {
      updateData.picture = req.body.picture.toString();
    }

    const updated = await Poste.findByIdAndUpdate(id, updateData, {
      new: true,
    });
    if (!updated) {
      return res.status(404).json({ errormessage: "Poste introuvable" });
    }

    return res.status(200).json({
      successmessage: "Poste mis à jour avec succès",
      data: updated,
    });
  } catch (error) {
    return res
      .status(500)
      .json({ errormessage: "Erreur du serveur: " + error.message });
  }
};

// DELETE /api/postes/:id
exports.deleteSinglePoste = async (req, res) => {
  const { id } = req.params;
  try {
    const deleted = await Poste.findByIdAndDelete(id);
    if (!deleted)
      return res.status(404).json({ errormessage: "Poste introuvable" });

    await Promise.all([
      Like.deleteMany({ posteId: id }),
      Save.deleteMany({ posteId: id }),
      Comment.deleteMany({ posteId: id }),
    ]);

    return res.status(200).json({
      successmessage: "Poste supprimé avec succès",
      data: deleted,
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

// PUT /api/postes/:id/approve
exports.approve = async (req, res) => {
  try {
    const updated = await Poste.findByIdAndUpdate(
      req.params.id,
      { $set: { status: "approved" } },
      { new: true }
    );
    if (!updated)
      return res.status(404).json({ errormessage: "Poste introuvable" });

    return res
      .status(200)
      .json({ successmessage: "Poste approuvé", data: updated });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

// PUT /api/postes/:id/decline
exports.decline = async (req, res) => {
  try {
    const updated = await Poste.findByIdAndUpdate(
      req.params.id,
      { $set: { status: "declined" } },
      { new: true }
    );
    if (!updated)
      return res.status(404).json({ errormessage: "Poste introuvable" });
    return res
      .status(200)
      .json({ successmessage: "Poste refusé", data: updated });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

exports.setPending = async (req, res) => {
  try {
    const updated = await Poste.findByIdAndUpdate(
      req.params.id,
      { $set: { status: "pending" } },
      { new: true }
    );
    if (!updated)
      return res.status(404).json({ errormessage: "Poste introuvable" });
    return res
      .status(200)
      .json({ successmessage: "Poste remis en attente", data: updated });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};

// PUBLIC FEED — approved only
exports.getAllPostesPublic = async (req, res) => {
  try {
    const items = await Poste.find(
      { status: "approved" },
      "userId content picture likesCount commentsCount savedCount createdAt"
    )
      .sort({ createdAt: -1 })
      .populate("userId", "username picture email");

    return res.status(200).json({
      successmessage: "Posts approuvés récupérés avec succès",
      data: items,
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur " + error.message });
  }
};

exports.listMine = async (req, res) => {
  try {
    const userId = req.user?.id || req.user?._id;
    const posts = await Poste.find({ userId }).sort({ createdAt: -1 });
    return res.json({ data: posts });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

exports.listMySavedPosts = async (req, res) => {
  try {
    const userId = req.user?.id || req.user?._id;
    const ids = await Save.find({ userId }).distinct("posteId");
    const posts = await Poste.find({ _id: { $in: ids } }).sort({
      createdAt: -1,
    });
    return res.json({ data: posts });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// ADMIN LIST
exports.getAllPostesAdmin = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.min(
      Math.max(parseInt(req.query.limit || "10", 10), 1),
      100
    );
    const skip = (page - 1) * limit;

    const { status, q } = req.query;
    const filter = {};
    if (status && ["pending", "approved", "declined"].includes(status)) {
      filter.status = status;
    }
    if (q && q.trim()) {
      filter.content = { $regex: q.trim(), $options: "i" };
    }

    const [items, total] = await Promise.all([
      Poste.find(
        filter,
        "userId content picture status likesCount savedCount commentsCount  createdAt updatedAt"
      )
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("userId", "username picture email role"),
      Poste.countDocuments(filter),
    ]);

    return res.status(200).json({
      successmessage: "Tous les posts ont été récupérés",
      data: items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur " + error.message });
  }
};