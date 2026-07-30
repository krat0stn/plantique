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
  create,
  update,
  remove,
} = require("../controllers/supplierController");

// Public
router.get("/with-stats", withStats);
router.get("/",    list);
router.get("/:id", getById);

// Admin
router.post(  "/",    verifyToken, isAdmin, upload.single("logo"), create);
router.put(   "/:id", verifyToken, isAdmin, upload.single("logo"), update);
router.delete("/:id", verifyToken, isAdmin, remove);

module.exports = router;
