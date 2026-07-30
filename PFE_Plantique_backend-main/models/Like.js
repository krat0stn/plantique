const mongoose = require("mongoose");
const { Schema } = mongoose;

const likeSchema = new Schema(
  {
    posteId: { type: Schema.Types.ObjectId, ref: "Poste", required: true },
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
  },
  { timestamps: true }
);

// un seul like par (post, user)
likeSchema.index({ posteId: 1, userId: 1 }, { unique: true });
likeSchema.index({ userId: 1, createdAt: -1 });
likeSchema.index({ posteId: 1, createdAt: -1 });

module.exports = mongoose.model("Like", likeSchema);
