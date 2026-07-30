const express = require("express");
const router = express.Router();
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");
const dashboard = require("../controllers/dashboardController");

router.get("/metrics", verifyToken, isAdmin, dashboard.metrics);

router.get(
  "/plants-analytics",
  verifyToken,
  isAdmin,
  dashboard.plantsAnalytics
);

module.exports = router;
