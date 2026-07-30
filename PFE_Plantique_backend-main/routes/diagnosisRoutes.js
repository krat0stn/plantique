const express = require("express");
const multer = require("multer");

const router = express.Router();
const {
  diagnosePlant,
  getMyDiagnoses,
  deleteDiagnosis,
} = require("../controllers/diagnosisController");
const { verifyToken } = require("../middlewares/authMiddleware");

const upload = multer({ storage: multer.memoryStorage() });

// POST /api/diagnosis
router.post("/", verifyToken, upload.single("image"), diagnosePlant);

// GET /api/diagnosis
router.get("/", verifyToken, getMyDiagnoses);
router.delete("/:id", verifyToken, deleteDiagnosis);

module.exports = router;
