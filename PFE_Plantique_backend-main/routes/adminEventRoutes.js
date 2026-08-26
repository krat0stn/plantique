const express = require("express");
const router = express.Router();

const multer = require("multer");
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

const eventController = require("../controllers/eventController");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

router.get("/",     verifyToken, isAdmin, eventController.list);
router.get("/:id",  verifyToken, isAdmin, eventController.getById);
router.post("/",    verifyToken, isAdmin, upload.single("image"), eventController.create);
router.put("/:id",  verifyToken, isAdmin, upload.single("image"), eventController.update);
router.delete("/:id", verifyToken, isAdmin, eventController.remove);

module.exports = router;
