const express = require("express");
const router = express.Router();

const multer = require("multer");
const { plantStorage } = require("../config/cloudinary");
const upload = multer({ storage: plantStorage });

const ctrl = require("../controllers/plantCareAdminController");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

// List + search + pagination
router.get("/", verifyToken, isAdmin, ctrl.listAdmin);

// Get by id
router.get("/:id", verifyToken, isAdmin, ctrl.getAdminById);

// Create (image file optional, field name "image")
router.post("/", verifyToken, isAdmin, upload.single("image"), ctrl.create);

// Update (replace image if provided)
router.put("/:id", verifyToken, isAdmin, upload.single("image"), ctrl.update);

// Delete plant
router.delete("/:id", verifyToken, isAdmin, ctrl.remove);

// Optional: delete only the image
router.delete("/:id/image", verifyToken, isAdmin, ctrl.removeImage);

module.exports = router;
