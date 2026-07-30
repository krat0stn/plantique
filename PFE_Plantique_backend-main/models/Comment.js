const mongoose = require("mongoose");
const { Schema } = mongoose;

const commentSchema = new Schema(
  {
    posteId: { type: Schema.Types.ObjectId, ref: "Poste", required: true },
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    content: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

commentSchema.index({ posteId: 1, createdAt: -1 });

module.exports = mongoose.model("Comment", commentSchema);
