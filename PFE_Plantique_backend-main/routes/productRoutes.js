const express = require("express");
const router  = express.Router();

const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");
const { list, getById, categories, create, update, remove } =
  require("../controllers/productController");

// Public
router.get("/categories", categories);
router.get("/",    list);
router.get("/:id", getById);

// Admin
router.post(  "/",    verifyToken, isAdmin, upload.single("image"), create);
router.put(   "/:id", verifyToken, isAdmin, upload.single("image"), update);
router.delete("/:id", verifyToken, isAdmin, remove);

module.exports = router;
