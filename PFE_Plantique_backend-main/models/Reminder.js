const mongoose = require("mongoose");

const reminderSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    plantSlug: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    plantName: {
      type: String,
      trim: true,
    },

    type: {
      type: String,
      enum: ["watering", "fertilizer", "misting", "pruning", "other"],
      required: true,
    },

    intervalDays: {
      type: Number,
      min: 1,
      default: 7,
    },

    nextDate: {
      type: Date,
      required: true,
    },

    timeOfDay: {
      type: String,
      default: "09:00",
    },

    notes: {
      type: String,
      trim: true,
    },

    active: {
      type: Boolean,
      default: true,
    },

    source: {
      type: String,
      enum: ["manual", "from_caretips"],
      default: "manual",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Reminder", reminderSchema);
