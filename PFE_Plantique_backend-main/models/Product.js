const mongoose = require("mongoose");
const { Schema } = mongoose;

const ProductSchema = new Schema(
  {
    name:          { type: String, required: true, trim: true },
    supplier:      { type: Schema.Types.ObjectId, ref: "Supplier", required: true },
    price:         { type: Number, required: true },
    category:      { type: String, required: true, trim: true },
    imageUrl:      { type: String, trim: true },
    imagePublicId: { type: String, trim: true },
    description:   { type: String, default: "" },
    quantity:      { type: Number, default: 0 },
    inStock:       { type: Boolean, default: true },
    isActive:      { type: Boolean, default: true },
  },
  { timestamps: true }
);

ProductSchema.index({ category: 1 });
ProductSchema.index({ supplier: 1 });
ProductSchema.index({ name: "text", description: "text" });

module.exports = mongoose.model("Product", ProductSchema);
