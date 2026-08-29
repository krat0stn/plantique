const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    type: {
      type: String,
      enum: ["like", "comment", "blog", "post", "reminder", "system", "mention"],
      default: "system",
      index: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },
    message: {
      type: String,
      required: true,
      trim: true,
    },

    fromUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Post",
    },
    blog: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Blog",
    },
    reminder: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Reminder",
    },

    plantSlug: String,
    plantName: String,

    read: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Notification", notificationSchema);
