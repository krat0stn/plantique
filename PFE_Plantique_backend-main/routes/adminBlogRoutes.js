const express = require("express");
const router = express.Router();

const multer = require("multer");
const { storage } = require("../config/cloudinary");
const upload = multer({ storage });

const blogController = require("../controllers/blogController");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

// ADMIN CRUD (file-only image via field name "image")
router.get("/", verifyToken, isAdmin, blogController.listAdmin);
router.post(
  "/",
  verifyToken,
  isAdmin,
  upload.single("image"),
  blogController.create
);
router.put(
  "/:id",
  verifyToken,
  isAdmin,
  upload.single("image"),
  blogController.update
);
router.delete("/:id", verifyToken, isAdmin, blogController.remove);
router.delete("/:id/image", verifyToken, isAdmin, blogController.removeImage);

module.exports = router;
