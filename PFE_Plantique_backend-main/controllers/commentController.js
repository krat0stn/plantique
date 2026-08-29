// controllers/commentController.js
const Comment = require("../models/Comment");
const Poste = require("../models/Poste");
const { notifyPostComment } = require("../utils/realtime");
const { createNotification } = require("../controllers/notificationController");
const { extractMentionUsernames, resolveMentionIds, notifyMentionedUsers } = require("../utils/mentions");

// Helper: populate comment userId or supplierId and return a unified author shape
async function populateComment(doc) {
  const obj = doc.toObject();

  if (doc.supplierId) {
    const Supplier = require("../models/Supplier");
    const supplier = await Supplier.findById(doc.supplierId)
      .select("firstName lastName shopName logoUrl");
    if (supplier) {
      obj.authorName = `${supplier.firstName} ${supplier.lastName}`;
      obj.authorPicture = supplier.logoUrl || "";
      obj.authorRole = "Supplier";
    }
  } else if (doc.userId) {
    const User = require("../models/User");
    const user = await User.findById(doc.userId).select("username picture");
    if (user) {
      obj.authorName = user.username;
      obj.authorPicture = user.picture || "";
      obj.authorRole = user.role;
    }
  }

  return obj;
}

// POST /api/postes/:id/comments
exports.create = async (req, res) => {
  try {
    const { id: posteId } = req.params;
    const { content, parentId } = req.body;
    const userId = req.user?.id;
    const role = req.user?.role;
    const isSupplier = role === "Supplier";

    if (!content || !content.trim()) {
      return res.status(400).json({ errormessage: "content est requis" });
    }
    const post = await Poste.findById(posteId).select("_id userId supplierId");
    if (!post)
      return res.status(404).json({ errormessage: "Poste introuvable" });

    // If replying to a comment, verify the parent exists and belongs to the same post
    if (parentId) {
      const parentComment = await Comment.findOne({ _id: parentId, posteId });
      if (!parentComment) {
        return res.status(404).json({ errormessage: "Commentaire parent introuvable" });
      }
    }

    const commentData = {
      posteId,
      content: content.trim(),
      parentId: parentId || null,
    };

    if (isSupplier) {
      commentData.supplierId = userId;
    } else {
      commentData.userId = userId;
    }

    // Extract @mentions from content
    const mentionUsernames = extractMentionUsernames(content);
    const mentionIds = await resolveMentionIds(mentionUsernames);
    if (mentionIds.length > 0) {
      commentData.mentions = mentionIds;
    }

    const comment = await Comment.create(commentData);

    await Poste.findByIdAndUpdate(posteId, {
      $inc: { commentsCount: 1 },
    });

    const populated = await populateComment(comment);

    notifyPostComment?.(post, comment);

    // Notify the post owner (if not the commenter)
    try {
      const postOwnerId = post.userId || post.supplierId;
      if (postOwnerId && String(postOwnerId) !== String(userId)) {
        await createNotification({
          userId: postOwnerId,
          type: "comment",
          title: "New comment on your post",
          message: `${populated.authorName || "Someone"} commented on your post.`,
          postId: post._id,
        });
      }
    } catch (notifyErr) {
      console.error("Comment notification error:", notifyErr.message);
    }

    // Notify mentioned users
    try {
      await notifyMentionedUsers({
        mentionedIds: mentionIds,
        actorUserId: userId,
        postId: post._id,
        actorName: populated.authorName || "Someone",
        contextType: "comment",
      });
    } catch (mentionErr) {
      console.error("Mention notification error:", mentionErr.message);
    }

    return res.status(201).json({
      successmessage: "Commentaire ajouté",
      data: {
        _id: populated._id,
        content: populated.content,
        authorName: populated.authorName,
        authorPicture: populated.authorPicture,
        authorRole: populated.authorRole,
        parentId: populated.parentId,
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
      Math.max(parseInt(req.query.limit || "50", 10), 1),
      100
    );
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      Comment.find({ posteId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Comment.countDocuments({ posteId }),
    ]);

    // Populate author info for each comment
    const populatedItems = await Promise.all(items.map(populateComment));

    // Two-pass nested build: first collect all, then attach replies to parents
    const commentMap = {};
    populatedItems.forEach((c) => {
      commentMap[c._id.toString()] = {
        _id: c._id,
        content: c.content,
        authorName: c.authorName || "Unknown",
        authorPicture: c.authorPicture || "",
        authorRole: c.authorRole || "",
        parentId: c.parentId,
        createdAt: c.createdAt,
        replies: [],
      };
    });

    const topLevel = [];
    Object.values(commentMap).forEach((commentData) => {
      if (commentData.parentId) {
        const parentIdStr = commentData.parentId.toString();
        if (commentMap[parentIdStr]) {
          commentMap[parentIdStr].replies.push(commentData);
        } else {
          topLevel.push(commentData);
        }
      } else {
        topLevel.push(commentData);
      }
    });

    return res.status(200).json({
      successmessage: "Commentaires récupérés",
      data: topLevel,
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
    const isSupplier = req.user?.role === "Supplier";

    const c = await Comment.findOne({ _id: commentId, posteId });
    if (!c)
      return res.status(404).json({ errormessage: "Commentaire introuvable" });

    // Allow if: comment owner, admin, or the post owner (supplier)
    let allowed = isAdmin;

    if (!allowed) {
      // Check if the commenter is the same user
      if (c.userId && String(c.userId) === String(userId)) allowed = true;
      if (c.supplierId && String(c.supplierId) === String(userId)) allowed = true;
    }

    if (!allowed && isSupplier) {
      const post = await Poste.findById(posteId).select("supplierId");
      if (post && String(post.supplierId) === String(userId)) {
        allowed = true;
      }
    }

    if (!allowed) {
      return res.status(403).json({ errormessage: "Non autorisé" });
    }

    // Also delete all replies to this comment
    const repliesToDelete = await Comment.find({ parentId: commentId });
    const deleteCount = 1 + repliesToDelete.length;

    await Comment.deleteMany({
      $or: [{ _id: commentId }, { parentId: commentId }],
    });

    await Poste.findByIdAndUpdate(posteId, {
      $inc: { commentsCount: -deleteCount },
    });

    return res.status(200).json({ successmessage: "Commentaire supprimé" });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};
