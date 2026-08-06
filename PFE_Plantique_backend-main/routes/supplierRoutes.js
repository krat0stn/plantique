const express = require("express");
const router  = express.Router();

const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB logo
});

const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");
const {
  list,
  getById,
  withStats,
  adminList,
  create,
  update,
  remove,
} = require("../controllers/supplierController");

// Public
router.get("/with-stats", withStats);
router.get("/",    list);

// Admin (must come before "/:id" so "admin" isn't treated as an id)
router.get("/admin", verifyToken, isAdmin, adminList);

router.get("/:id", getById);

// Admin
router.post(  "/",    verifyToken, isAdmin, upload.single("logo"), create);
router.put(   "/:id", verifyToken, isAdmin, upload.single("logo"), update);
router.delete("/:id", verifyToken, isAdmin, remove);

module.exports = router;