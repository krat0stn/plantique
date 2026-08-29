const mongoose = require("mongoose");

const identificationSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Account",
      required: true,
    },
    plantName: {
      type: String,
      required: true,
      trim: true,
    },
    confidence: {
      type: Number,
      required: true,
    },
    imageUrl: {
      type: String,
    },
    savedToLibrary: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Identification", identificationSchema);
