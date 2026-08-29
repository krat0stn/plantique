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
    const accounts = await Account.find({
      role: { $ne: "Admin" },
      $or: [
        { username: { $regex: q, $options: "i" } },
        { firstName: { $regex: q, $options: "i" } },
        { lastName: { $regex: q, $options: "i" } },
        { shopName: { $regex: q, $options: "i" } },
      ],
    })
      .select("username picture role firstName lastName logoUrl")
      .limit(10);

    const data = accounts.map((a) => {
      const displayName = a.role === "Supplier"
        ? `${a.firstName || ""} ${a.lastName || ""}`.trim() || a.username || "Supplier"
        : a.username;
      // mentionTag is a handle with no spaces, used for @ insertion in text
      const mentionTag = displayName.replace(/\s+/g, "_").toLowerCase();
      return {
        username: mentionTag,
        displayName,
        picture: a.role === "Supplier" ? (a.logoUrl || a.picture || "") : (a.picture || ""),
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
    const suppliers = await Account.find({
      role: "Supplier",
      $or: [
        { firstName: { $regex: q, $options: "i" } },
        { lastName: { $regex: q, $options: "i" } },
        { shopName: { $regex: q, $options: "i" } },
      ],
    })
      .select("firstName lastName logoUrl")
      .limit(10);
    const data = suppliers.map((s) => ({
      username: `${s.firstName} ${s.lastName}`,
      picture: s.logoUrl || "",
    }));
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
      .populate("authorId", "username picture role firstName lastName logoUrl")
      .sort({ createdAt: -1 });
    res.json({ data: posts });
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
