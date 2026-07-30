const mongoose = require("mongoose");

const recommendationSchema = new mongoose.Schema(
  {
    disease: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    language: {
      type: String,
      default: "en",
    },
    symptoms: { type: String },
    prevention: { type: String },
    recommendations: { type: String },
    treatment: { type: String },
    rawText: { type: String },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: { createdAt: "createdAt", updatedAt: "updatedAt" },
  }
);

recommendationSchema.index({ disease: 1 }, { unique: true });

module.exports = mongoose.model("Recommendation", recommendationSchema);
