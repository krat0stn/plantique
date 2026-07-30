// controllers/dashboardController.js
const User = require("../models/User");
const Blog = require("../models/Blog");
const Review = require("../models/Review");
const Poste = require("../models/Poste");

// NEW: models for plants & AR
const PlantCare = require("../models/Plant");
const ArModel = require("../models/Ar");

//  count by month for last 12 months (kept as-is for /metrics)
async function countByMonth(Model) {
  const since = new Date();
  since.setMonth(since.getMonth() - 11);
  const agg = await Model.aggregate([
    { $match: { createdAt: { $gte: since } } },
    {
      $group: {
        _id: { y: { $year: "$createdAt" }, m: { $month: "$createdAt" } },
        count: { $sum: 1 },
      },
    },
    { $sort: { "_id.y": 1, "_id.m": 1 } },
  ]);

  // Build a fixed 12-month series
  const out = [];
  const cursor = new Date(since.getFullYear(), since.getMonth(), 1);
  const map = new Map(agg.map((d) => [`${d._id.y}-${d._id.m}`, d.count]));
  for (let i = 0; i < 12; i++) {
    const key = `${cursor.getFullYear()}-${cursor.getMonth() + 1}`;
    out.push({
      year: cursor.getFullYear(),
      month: cursor.getMonth() + 1,
      count: map.get(key) || 0,
    });
    cursor.setMonth(cursor.getMonth() + 1);
  }
  return out;
}

// ---------- Existing dashboard metrics ----------
exports.metrics = async (req, res) => {
  try {
    const pendingRegex = /^pending$/i;

    const [
      totalUsers,
      totalBlogs,
      totalPosts,
      pendingPosts,
      reviewsAgg,
      lastReviews,
      lastBlogs,
      usersSeries,
      postsSeries,
      blogsSeries,
    ] = await Promise.all([
      User.countDocuments({ role: { $ne: "Admin" } }),
      Blog.countDocuments({}),
      Poste.countDocuments({}),
      Poste.countDocuments({ status: { $regex: pendingRegex } }),
      Review.aggregate([
        { $group: { _id: null, avg: { $avg: "$rating" }, count: { $sum: 1 } } },
      ]),
      Review.find({})
        .sort({ createdAt: -1 })
        .limit(5)
        .populate("user", "username email"),
      Blog.find({})
        .sort({ createdAt: -1 })
        .limit(5)
        .populate("author", "username email"),
      countByMonth(User),
      countByMonth(Poste),
      countByMonth(Blog),
    ]);

    const avgReview = reviewsAgg[0]?.avg ?? 0;
    const reviewsCount = reviewsAgg[0]?.count ?? 0;

    return res.json({
      cards: {
        totalUsers,
        totalBlogs,
        totalPosts,
        pendingPosts,
        avgRating: Math.round(avgReview * 10) / 10,
        reviewsCount,
      },
      latest: {
        reviews: lastReviews,
        blogs: lastBlogs,
      },
      series: {
        users: usersSeries,
        posts: postsSeries,
        blogs: blogsSeries,
      },
    });
  } catch (err) {
    return res.status(500).json({ errormessage: err.message });
  }
};

// ---------- NEW: Plants & AR analytics for dashboard extras ----------

// Build last 12 month keys in UTC as "YYYY-MM"
function last12MonthKeys() {
  const now = new Date();
  const keys = [];
  for (let i = 11; i >= 0; i--) {
    const d = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1)
    );
    const y = d.getUTCFullYear();
    const m = d.getUTCMonth() + 1;
    keys.push(`${y}-${String(m).padStart(2, "0")}`);
  }
  return keys;
}
function monthStartUTC(y, m) {
  return new Date(Date.UTC(y, m - 1, 1, 0, 0, 0));
}

exports.plantsAnalytics = async (req, res) => {
  try {
    const monthKeys = last12MonthKeys();
    const [startY, startM] = monthKeys[0]
      .split("-")
      .map((n) => parseInt(n, 10));
    const startDate = monthStartUTC(startY, startM);

    // Monthly counts for PlantCare
    const plantsAgg = await PlantCare.aggregate([
      { $match: { createdAt: { $gte: startDate } } },
      {
        $group: {
          _id: { y: { $year: "$createdAt" }, m: { $month: "$createdAt" } },
          count: { $sum: 1 },
        },
      },
    ]);

    // Monthly counts for ArModel
    const arAgg = await ArModel.aggregate([
      { $match: { createdAt: { $gte: startDate } } },
      {
        $group: {
          _id: { y: { $year: "$createdAt" }, m: { $month: "$createdAt" } },
          count: { $sum: 1 },
        },
      },
    ]);

    const plantsMap = new Map(
      plantsAgg.map((r) => [
        `${r._id.y}-${String(r._id.m).padStart(2, "0")}`,
        r.count,
      ])
    );
    const arMap = new Map(
      arAgg.map((r) => [
        `${r._id.y}-${String(r._id.m).padStart(2, "0")}`,
        r.count,
      ])
    );

    const series = {
      months: monthKeys,
      plants: monthKeys.map((k) => plantsMap.get(k) ?? 0),
      arModels: monthKeys.map((k) => arMap.get(k) ?? 0),
    };

    const [totalPlants, totalArModels] = await Promise.all([
      PlantCare.countDocuments(),
      ArModel.countDocuments(),
    ]);

    // Plant type distribution (split by • , ; /)
    const typeDocs = await PlantCare.find().select("plantType").lean();
    const typeCount = new Map();
    const splitter = /[•,;/]/;
    for (const d of typeDocs) {
      const raw = String(d.plantType || "");
      const parts = raw
        .split(splitter)
        .map((t) => t.trim())
        .filter(Boolean);
      for (const t of parts) {
        const key = t.charAt(0).toUpperCase() + t.slice(1);
        typeCount.set(key, (typeCount.get(key) || 0) + 1);
      }
    }
    const plantTypes = Array.from(typeCount.entries())
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);

    // AR coverage: with thumbnail vs without
    const [arWithThumb, arWithoutThumb] = await Promise.all([
      ArModel.countDocuments({ thumbPublicId: { $exists: true, $ne: null } }),
      ArModel.countDocuments({
        $or: [{ thumbPublicId: { $exists: false } }, { thumbPublicId: null }],
      }),
    ]);
    const arCoverage = [
      { name: "With thumbnail", count: arWithThumb },
      { name: "No thumbnail", count: arWithoutThumb },
    ];

    return res.json({
      cards: { totalPlants, totalArModels },
      series,
      breakdown: { plantTypes, arCoverage },
    });
  } catch (e) {
    return res.status(500).json({ errormessage: e.message });
  }
};
