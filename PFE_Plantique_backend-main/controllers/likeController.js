// controllers/likeController.js
const Like = require("../models/Like");
const Poste = require("../models/Poste");
const User = require("../models/User");
const { createNotification } = require("../controllers/notificationController");

// PUT /api/postes/:id/like
exports.toggle = async (req, res) => {
  try {
    const posteId = req.params.id;
    const userId = req.user?.id || req.user?._id;

    const found = await Like.findOne({ posteId, userId });
    let liked;

    if (found) {
      // ➖ On retire le like
      await Like.deleteOne({ _id: found._id });
      await Poste.findByIdAndUpdate(posteId, { $inc: { likesCount: -1 } });
      liked = false;
    } else {
      // ➕ On ajoute un like
      await Like.create({ posteId, userId });
      await Poste.findByIdAndUpdate(posteId, { $inc: { likesCount: 1 } });
      liked = true;
    }

    // On récupère le post avec son owner
    const post = await Poste.findById(posteId)
      .select("likesCount userId")
      .populate("userId", "username");

    const likesCount = post?.likesCount ?? 0;

    // 🔔 Notification si on vient de liker (pas un unlike) et si ce n’est pas notre propre post
    if (
      liked &&
      post &&
      post.userId &&
      String(post.userId._id) !== String(userId)
    ) {
      try {
        await createNotification({
          userId: post.userId._id,
          type: "like",
          title: "New like on your post",
          message: `${req.user?.username || "Someone"} liked your post.`,
          postId: post._id,
        });
      } catch (notifyErr) {
        console.error("Error creating like notification:", notifyErr.message);
      }
    }

    return res.status(200).json({
      successmessage: "Like toggled",
      data: { liked, likesCount },
    });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// GET /api/postes/:id/likes
exports.listByPost = async (req, res) => {
  try {
    const items = await Like.find({ posteId: req.params.id }).populate(
      "userId",
      "username picture"
    );
    return res.status(200).json({ data: items });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// GET /api/postes/liked/me
exports.myLikedPosts = async (req, res) => {
  try {
    const items = await Like.find({ userId: req.user.id }).select("posteId");
    return res.status(200).json({ data: items.map((i) => i.posteId) });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};
