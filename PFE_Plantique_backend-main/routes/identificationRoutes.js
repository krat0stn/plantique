const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const identificationController = require("../controllers/identificationController");

// GET /api/identifications
router.get("/", verifyToken, identificationController.listMyLibrary);

// POST /api/identifications/:id/save
router.post("/:id/save", verifyToken, identificationController.saveToLibrary);

// DELETE /api/identifications/:id
router.delete(
  "/:id",
  verifyToken,
  identificationController.deleteIdentification
);

module.exports = router;
