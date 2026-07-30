const mongoose = require("mongoose");
const { Schema } = mongoose;

const reviewSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: "User", required: true },
    rating: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, trim: true, maxlength: 2000 },
  },
  { timestamps: true }
);

reviewSchema.index({ createdAt: -1 });
reviewSchema.index({ rating: 1 });
reviewSchema.index({ user: 1 });

module.exports = mongoose.model("Review", reviewSchema);
