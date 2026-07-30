const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const reminderController = require("../controllers/reminderController");

router.use(verifyToken);

// GET /api/reminders
router.get("/", reminderController.listMyReminders);

// POST /api/reminders
router.post("/", reminderController.createReminder);

// PATCH /api/reminders/:id
router.patch("/:id", reminderController.updateReminder);

// DELETE /api/reminders/:id
router.delete("/:id", reminderController.deleteReminder);

module.exports = router;
