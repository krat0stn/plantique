const mongoose = require("mongoose");
const { Schema } = mongoose;

const blogSchema = new Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 200 },
    content: { type: String, required: true, trim: true },
    excerpt: { type: String, trim: true, maxlength: 500 },
    imageUrl: { type: String, trim: true },
    imagePublicId: { type: String, trim: true },
    author: { type: Schema.Types.ObjectId, ref: "User", required: true },
  },
  { timestamps: true },
);

blogSchema.index({ createdAt: -1 });
blogSchema.index({ title: "text", content: "text", excerpt: "text" });

blogSchema.pre("validate", function (next) {
  if (!this.excerpt && this.content) {
    const text = this.content.replace(/<[^>]*>/g, "");
    this.excerpt = text.substring(0, 160).trim();
  }
  next();
});

module.exports = mongoose.model("Blog", blogSchema);
