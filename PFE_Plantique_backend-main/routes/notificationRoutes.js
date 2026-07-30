const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const notificationController = require("../controllers/notificationController");

router.get("/", verifyToken, notificationController.listMyNotifications);
router.patch("/read-all", verifyToken, notificationController.markAllAsRead);
router.patch("/:id/read", verifyToken, notificationController.markAsRead);
router.delete("/:id", verifyToken, notificationController.deleteNotification);

module.exports = router;
