// routes/arRoutes.js
const express = require("express");
const router = express.Router();

const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB; adjust to your Cloudinary plan
  },
});

const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");
const ar = require("../controllers/arController");
const { evaluate } = require("../controllers/evaluateController");

// Optional: Cloudinary catalog view (unchanged)
router.get("/models", ar.listModels);

// Environment evaluation — public (uses GPS coords + plant id)
router.post("/evaluate", evaluate);

// Public read
router.get("/", ar.list);
router.get("/:id", ar.getById);

// Admin-only mutate (accept both files)
router.post(
  "/",
  verifyToken,
  isAdmin,
  upload.fields([
    { name: "model", maxCount: 1 },
    { name: "thumbnail", maxCount: 1 },
  ]),
  ar.create
);

router.put(
  "/:id",
  verifyToken,
  isAdmin,
  upload.fields([
    { name: "model", maxCount: 1 },
    { name: "thumbnail", maxCount: 1 },
  ]),
  ar.update
);

router.delete("/:id", verifyToken, isAdmin, ar.remove);

module.exports = router;
