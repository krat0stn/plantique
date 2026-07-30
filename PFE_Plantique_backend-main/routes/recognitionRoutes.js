const express = require("express");
const multer = require("multer");
const {
  identifyFromFile,
  identifyFromUrl,
} = require("../controllers/recognitionController");
const router = express.Router();
const upload = multer();
const { verifyToken } = require("../middlewares/authMiddleware");
const recognitionController = require("../controllers/recognitionController");

router.post("/identify", upload.single("image"), identifyFromFile);
router.post(
  "/file",
  verifyToken,
  upload.single("file"),
  recognitionController.identifyFromFile
);
module.exports = router;
