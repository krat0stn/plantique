const mongoose = require("mongoose");
const { Schema } = mongoose;

const posteSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    content: { type: String, required: true, trim: true },
    picture: { type: String },
    status: {
      type: String,
      enum: ["pending", "approved", "declined"],
      default: "pending",
    },
    // Compteurs
    likesCount: { type: Number, default: 0 },
    savedCount: { type: Number, default: 0 },
    commentsCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

posteSchema.index({ userId: 1, createdAt: -1 });
posteSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model("Poste", posteSchema);
