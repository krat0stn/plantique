const mongoose = require("mongoose");
const Review = require("../models/Review");

const uid = (req, res) =>
  (req.user && (req.user._id || req.user.id)) ||
  (res.locals && (res.locals.userId || res.locals.userID)) ||
  null;

// Public: list all reviews
exports.listPublic = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "10", 10), 1);

    const [data, total] = await Promise.all([
      Review.find({})
        .populate("user", "username")
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      Review.countDocuments({}),
    ]);

    res.json({
      data,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    res.status(400).json({ errormessage: err.message });
  }
};

// Public: quick summary
exports.summary = async (_req, res) => {
  try {
    const agg = await Review.aggregate([
      { $group: { _id: null, avg: { $avg: "$rating" }, count: { $sum: 1 } } },
    ]);
    const avg = agg[0]?.avg || 0;
    const count = agg[0]?.count || 0;
    res.json({
      averageRating: Math.round((avg + Number.EPSILON) * 10) / 10,
      reviewsCount: count,
    });
  } catch (err) {
    res.status(400).json({ errormessage: err.message });
  }
};

// User: create (unlimited)
exports.create = async (req, res) => {
  try {
    const userId = uid(req, res);
    if (!userId) return res.status(401).json({ errormessage: "Unauthorized" });

    const { rating, comment } = req.body;
    const ratingNum = Number(rating);
    if (!Number.isFinite(ratingNum) || ratingNum < 1 || ratingNum > 5) {
      return res
        .status(400)
        .json({ errormessage: "rating must be a number between 1 and 5" });
    }

    const review = await Review.create({
      user: userId,
      rating: ratingNum,
      comment,
    });

    res.status(201).json(review);
  } catch (err) {
    res.status(400).json({ errormessage: err.message });
  }
};

// Admin: list all
exports.adminList = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "10", 10), 1);

    const [data, total] = await Promise.all([
      Review.find({})
        .populate("user", "username email role")
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      Review.countDocuments({}),
    ]);

    res.json({
      data,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    res.status(400).json({ errormessage: err.message });
  }
};

// Admin: delete any review
exports.adminRemove = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ errormessage: "Invalid review id" });
    }

    const review = await Review.findByIdAndDelete(id);
    if (!review)
      return res.status(404).json({ errormessage: "Review not found" });

    res.json({ success: true, deletedId: id });
  } catch (err) {
    res.status(400).json({ errormessage: err.message });
  }
};
