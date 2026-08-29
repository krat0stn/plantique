// controllers/likeController.js
const Like = require("../models/Like");
const Poste = require("../models/Poste");
const { createNotification } = require("../controllers/notificationController");

// PUT /api/postes/:id/like
exports.toggle = async (req, res) => {
  try {
    const posteId = req.params.id;
    const userId = req.user?.id || req.user?._id;

    const found = await Like.findOne({ posteId, userId });
    let liked;

    if (found) {
      await Like.deleteOne({ _id: found._id });
      await Poste.findByIdAndUpdate(posteId, { $inc: { likesCount: -1 } });
      liked = false;
    } else {
      await Like.create({ posteId, userId });
      await Poste.findByIdAndUpdate(posteId, { $inc: { likesCount: 1 } });
      liked = true;
    }

    const post = await Poste.findById(posteId)
      .select("likesCount authorId")
      .populate("authorId", "username");

    const likesCount = post?.likesCount ?? 0;

    if (
      liked &&
      post &&
      post.authorId &&
      String(post.authorId._id) !== String(userId)
    ) {
      try {
        await createNotification({
          userId: post.authorId._id,
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
