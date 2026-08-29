const mongoose = require("mongoose");
const { Schema } = mongoose;

const posteSchema = new Schema(
  {
    // User who authored (regular user posts). Optional when supplierId is set.
    userId: { type: Schema.Types.ObjectId, ref: "User", required: false },
    // Supplier who authored (supplier-created posts)
    supplierId: { type: Schema.Types.ObjectId, ref: "Supplier", required: false },
    content: { type: String, required: true, trim: true },
    picture: { type: String },
    status: {
      type: String,
      enum: ["pending", "approved", "declined"],
      default: "pending",
    },
    // Counters
    likesCount: { type: Number, default: 0 },
    savedCount: { type: Number, default: 0 },
    commentsCount: { type: Number, default: 0 },
    // Mentions
    mentions: [{ type: Schema.Types.ObjectId, ref: "User" }],
  },
  { timestamps: true }
);

posteSchema.index({ userId: 1, createdAt: -1 });
posteSchema.index({ supplierId: 1, createdAt: -1 });
posteSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model("Poste", posteSchema);
