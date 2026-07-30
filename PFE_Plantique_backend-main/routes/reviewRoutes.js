// routes/reviewRoutes.js
const express = require("express");
const router = express.Router();
const c = require("../controllers/reviewController");
const {
  verifyToken,
  isUser,
  isAdmin,
} = require("../middlewares/authMiddleware");

// Public
router.get("/", c.listPublic);
router.get("/summary", c.summary);

// User
router.post("/", verifyToken, isUser, c.create);

// Admin
router.get("/admin", verifyToken, isAdmin, c.adminList);
router.delete("/admin/:id", verifyToken, isAdmin, c.adminRemove);

module.exports = router;
