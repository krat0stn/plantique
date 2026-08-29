const mongoose = require("mongoose");
const { Schema } = mongoose;

const posteSchema = new Schema(
  {
    authorId: { type: Schema.Types.ObjectId, ref: "Account", required: false },
    content: { type: String, required: true, trim: true },
    picture: { type: String },
    status: {
      type: String,
      enum: ["pending", "approved", "declined"],
      default: "pending",
    },
    likesCount: { type: Number, default: 0 },
    savedCount: { type: Number, default: 0 },
    commentsCount: { type: Number, default: 0 },
    mentions: [{ type: Schema.Types.ObjectId, ref: "Account" }],
  },
  { timestamps: true }
);

posteSchema.index({ authorId: 1, createdAt: -1 });
posteSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model("Poste", posteSchema);
