// routes/supplierDashboardRoutes.js
const express = require("express");
const router  = express.Router();

const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const { verifyToken, isSupplier } = require("../middlewares/authMiddleware");
const commentController = require("../controllers/commentController");
const Account = require("../models/Account");
const Supplier = require("../models/Supplier");
const Poste = require("../models/Poste");

const {
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  importProducts,
  listPosts,
  createPost,
  updatePost,
  deletePost,
  listBlogs,
  createBlog,
  updateBlog,
  deleteBlog,
  listPurchases,
  recordPurchase,
  getReceipt,
  getStats,
  getProfile,
} = require("../controllers/supplierDashboardController");

// All routes require a valid Supplier JWT
router.use(verifyToken, isSupplier);

// Profile
router.get("/me", getProfile);

// Unified search for @mentions (users + suppliers in one query)
router.get("/users/search", async (req, res) => {
  try {
    const q = (req.query.q || "").trim();
    if (q.length < 1) return res.json({ data: [] });

    // Search in accounts
    const accounts = await Account.find({
      role: { $ne: "Admin" },
      $or: [
        { username: { $regex: q, $options: "i" } },
        { email: { $regex: q, $options: "i" } },
      ],
    })
      .select("username picture role")
      .limit(10);

    // Get supplier details for supplier accounts
    const supplierAccountIds = accounts
      .filter((a) => a.role === "Supplier")
      .map((a) => a._id);

    const suppliers = await Supplier.find({
      accountId: { $in: supplierAccountIds },
      $or: [
        { firstName: { $regex: q, $options: "i" } },
        { lastName: { $regex: q, $options: "i" } },
        { shopName: { $regex: q, $options: "i" } },
      ],
    }).select("accountId firstName lastName logoUrl");

    const supplierMap = new Map(
      suppliers.map((s) => [s.accountId.toString(), s])
    );

    const data = accounts.map((a) => {
      const supplier = supplierMap.get(a._id.toString());
      const displayName = a.role === "Supplier"
        ? supplier
          ? `${supplier.firstName || ""} ${supplier.lastName || ""}`.trim() || a.username || "Supplier"
          : a.username || "Supplier"
        : a.username;
      // mentionTag is a handle with no spaces, used for @ insertion in text
      const mentionTag = displayName.replace(/\s+/g, "_").toLowerCase();
      return {
        username: mentionTag,
        displayName,
        picture: a.role === "Supplier" ? (supplier?.logoUrl || a.picture || "") : (a.picture || ""),
        role: a.role,
      };
    });

    res.json({ data });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Backward-compat: same endpoint, different path
router.get("/suppliers/search", async (req, res) => {
  try {
    const q = (req.query.q || "").trim();
    if (q.length < 1) return res.json({ data: [] });

    // Search in suppliers collection
    const suppliers = await Supplier.find({
      $or: [
        { firstName: { $regex: q, $options: "i" } },
        { lastName: { $regex: q, $options: "i" } },
        { shopName: { $regex: q, $options: "i" } },
      ],
    }).select("accountId firstName lastName logoUrl").limit(10);

    // Get account data for these suppliers
    const accountIds = suppliers.map((s) => s.accountId);
    const accounts = await Account.find({
      _id: { $in: accountIds },
    }).select("username");

    const accountMap = new Map(
      accounts.map((a) => [a._id.toString(), a])
    );

    const data = suppliers.map((s) => {
      const account = accountMap.get(s.accountId.toString());
      return {
        username: account?.username || `${s.firstName} ${s.lastName}`,
        picture: s.logoUrl || "",
      };
    });

    res.json({ data });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Posts where the current supplier is mentioned (in post content OR in comments), approved only
router.get("/posts/mentioned-me", async (req, res) => {
  try {
    const userId = req.user.id;
    const Comment = require("../models/Comment");

    const postIdsFromPosts = await Poste.find({ mentions: userId }).distinct("_id");
    const postIdsFromComments = await Comment.find({ mentions: userId }).distinct("posteId");

    const allPostIds = [...new Set([
      ...postIdsFromPosts.map(id => id.toString()),
      ...postIdsFromComments.map(id => id.toString()),
    ])];

    const posts = await Poste.find({ _id: { $in: allPostIds }, status: "approved" })
      .populate("authorId", "username picture role")
      .sort({ createdAt: -1 });

    // Enrich posts with supplier data if author is a supplier
    const enrichedPosts = await Promise.all(
      posts.map(async (post) => {
        const postData = post.toObject();
        if (postData.authorId?.role === "Supplier") {
          const supplier = await Supplier.findOne({ accountId: postData.authorId._id })
            .select("firstName lastName logoUrl");
          if (supplier) {
            postData.authorId = {
              ...postData.authorId,
              firstName: supplier.firstName,
              lastName: supplier.lastName,
              logoUrl: supplier.logoUrl,
            };
          }
        }
        return postData;
      })
    );

    res.json({ data: enrichedPosts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Products
router.get("/products",        listProducts);
router.post("/products/import", upload.single("file"), importProducts);
router.post("/products",       upload.single("image"), createProduct);
router.put("/products/:id",    upload.single("image"), updateProduct);
router.delete("/products/:id", deleteProduct);

// Posts
router.get("/posts",        listPosts);
router.post("/posts",       upload.single("picture"), createPost);
router.put("/posts/:id",    upload.single("picture"), updatePost);
router.delete("/posts/:id", deletePost);

// Post Comments
router.post("/posts/:id/comments",       commentController.create);
router.get("/posts/:id/comments",        commentController.list);
router.delete("/posts/:id/comments/:commentId", commentController.remove);

// Blogs
router.get("/blogs",        listBlogs);
router.post("/blogs",       upload.single("image"), createBlog);
router.put("/blogs/:id",    upload.single("image"), updateBlog);
router.delete("/blogs/:id", deleteBlog);

// Purchases
router.get("/purchases", listPurchases);
router.get("/purchases/:id/receipt", getReceipt);
router.post("/purchases/record", recordPurchase);

// Stats
router.get("/stats", getStats);

module.exports = router;
