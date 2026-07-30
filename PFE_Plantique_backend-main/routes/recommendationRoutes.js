// backend/routes/diseaseRoutes.js
const express = require("express");
const router = express.Router();
const recommendationController = require("../controllers/recommendationController.js");

// POST /api/disease/recommendation
router.post(
  "/recommendation/:disease",
  recommendationController.getDiseaseRecommendation
);

module.exports = router;
