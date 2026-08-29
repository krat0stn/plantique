const mongoose = require("mongoose");
const { Schema } = mongoose;

const commentSchema = new Schema(
  {
    posteId: { type: Schema.Types.ObjectId, ref: "Poste", required: true },
    authorId: { type: Schema.Types.ObjectId, ref: "Account", default: null },
    content: { type: String, required: true, trim: true },
    parentId: { type: Schema.Types.ObjectId, ref: "Comment", default: null },
    mentions: [{ type: Schema.Types.ObjectId, ref: "Account" }],
  },
  { timestamps: true }
);

commentSchema.index({ posteId: 1, createdAt: -1 });
commentSchema.index({ parentId: 1 });

module.exports = mongoose.model("Comment", commentSchema);
