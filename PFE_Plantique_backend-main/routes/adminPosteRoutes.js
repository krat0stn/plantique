const express = require("express");
const router = express.Router();
const posteController = require("../controllers/posteController");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

// GET /api/admin/postes?status=&q=&page=&limit=
router.get("/", verifyToken, isAdmin, posteController.getAllPostesAdmin);

module.exports = router;
