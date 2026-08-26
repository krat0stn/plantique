// routes/supplierDashboardRoutes.js
const express = require("express");
const router  = express.Router();

const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const { verifyToken, isSupplier } = require("../middlewares/authMiddleware");

const {
  // Products
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  importProducts,
  // Posts
  listPosts,
  createPost,
  updatePost,
  deletePost,
  // Blogs
  listBlogs,
  createBlog,
  updateBlog,
  deleteBlog,
  // Purchases
  listPurchases,
  recordPurchase,
  getReceipt,
  // Stats
  getStats,
  // Profile
  getProfile,
} = require("../controllers/supplierDashboardController");

// All routes require a valid Supplier JWT
router.use(verifyToken, isSupplier);

// Profile
router.get("/me", getProfile);

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

// Blogs
router.get("/blogs",        listBlogs);
router.post("/blogs",       upload.single("image"), createBlog);
router.put("/blogs/:id",    upload.single("image"), updateBlog);
router.delete("/blogs/:id", deleteBlog);

// Purchases (read-only for suppliers + record endpoint for the booking flow)
router.get("/purchases", listPurchases);
router.get("/purchases/:id/receipt", getReceipt);
// Called by the existing booking/purchase flow (verifyToken already included above,
// but we also allow this via the global verifyToken without isSupplier restriction
// so that user-side booking code can call it. The route below is a separate path.
// For now, it's accessible to authenticated suppliers.
router.post("/purchases/record", recordPurchase);

// Stats (overview cards + yearly monthly curve)
router.get("/stats", getStats);

module.exports = router;