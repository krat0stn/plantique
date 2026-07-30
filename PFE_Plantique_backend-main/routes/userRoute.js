// routes/users.js
const express = require("express");
const router = express.Router();

const userController = require("../controllers/userController");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

// Multer + Cloudinary storage
const multer = require("multer");
const { storage } = require("../config/cloudinary");
const upload = multer({ storage });

// Put /me routes BEFORE '/:id'
router.get("/me", verifyToken, userController.getMe);
router.put(
  "/me",
  verifyToken,
  upload.single("picture"),
  userController.updateMe
);
// Back-compat so old clients using PATCH won't 404
router.patch(
  "/me",
  verifyToken,
  upload.single("picture"),
  userController.updateMe
);

router.put("/me/password", verifyToken, userController.changePassword);

// Admin / general CRUD
router.get("/", verifyToken, isAdmin, userController.getAllUsers);
router.get("/:id", verifyToken, userController.getSingleUser);

router.post(
  "/",
  verifyToken,
  isAdmin,
  upload.single("picture"),
  userController.create
);
router.put(
  "/:id",
  verifyToken,
  isAdmin,
  upload.single("picture"),
  userController.updateSingleUser
);
router.patch(
  "/:id",
  verifyToken,
  isAdmin,
  upload.single("picture"),
  userController.updateSingleUser
);

router.delete("/:id", verifyToken, isAdmin, userController.deleteSingleUser);

module.exports = router;
