// controllers/commentController.js
const Comment = require("../models/Comment");
const Poste = require("../models/Poste");
const { notifyPostComment } = require("../utils/realtime");
const { createNotification } = require("../controllers/notificationController");

// POST /api/postes/:id/comments
exports.create = async (req, res) => {
  try {
    const { id: posteId } = req.params;
    const { content } = req.body;
    const userId = req.user?.id;

    if (!content || !content.trim()) {
      return res.status(400).json({ errormessage: "content est requis" });
    }
    const post = await Poste.findById(posteId).select("_id userId");
    if (!post)
      return res.status(404).json({ errormessage: "Poste introuvable" });

    const comment = await Comment.create({
      posteId,
      userId,
      content: content.trim(),
    });

    // 🆕 incrémente le compteur
    await Poste.findByIdAndUpdate(posteId, {
      $inc: { commentsCount: 1 },
    });

    const populated = await Comment.findById(comment._id).populate(
      "userId",
      "username picture email"
    );

    notifyPostComment?.(post, comment);

    return res.status(201).json({
      successmessage: "Commentaire ajouté",
      data: {
        _id: populated._id,
        content: populated.content,
        userId: populated.userId,
        createdAt: populated.createdAt,
      },
    });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// GET /api/postes/:id/comments?page=&limit=
exports.list = async (req, res) => {
  try {
    const { id: posteId } = req.params;
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.min(
      Math.max(parseInt(req.query.limit || "20", 10), 1),
      100
    );
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      Comment.find({ posteId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("userId", "username picture email"),
      Comment.countDocuments({ posteId }),
    ]);

    return res.status(200).json({
      successmessage: "Commentaires récupérés",
      data: items.map((c) => ({
        _id: c._id,
        content: c.content,
        userId: c.userId,
        createdAt: c.createdAt,
      })),
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// DELETE /api/postes/:id/comments/:commentId
exports.remove = async (req, res) => {
  try {
    const { id: posteId, commentId } = req.params;
    const userId = req.user?.id;
    const isAdmin = req.user?.role === "Admin";

    const c = await Comment.findOne({ _id: commentId, posteId });
    if (!c)
      return res.status(404).json({ errormessage: "Commentaire introuvable" });

    if (c.userId.toString() !== String(userId) && !isAdmin) {
      return res.status(403).json({ errormessage: "Non autorisé" });
    }

    await Comment.deleteOne({ _id: commentId });

    // 🆕 décrémente le compteur (sans passer < 0)
    await Poste.findByIdAndUpdate(posteId, {
      $inc: { commentsCount: -1 },
    });

    return res.status(200).json({ successmessage: "Commentaire supprimé" });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};
