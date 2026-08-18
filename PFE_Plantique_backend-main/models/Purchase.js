const mongoose = require("mongoose");
const { Schema } = mongoose;

/**
 * Purchase – automatically created when a user books/purchases a product.
 * Each purchase is scoped to a supplier so they can see their own sales.
 */
const PurchaseSchema = new Schema(
  {
    supplierId:  { type: Schema.Types.ObjectId, ref: "Supplier", required: true, index: true },
    productId:   { type: Schema.Types.ObjectId, ref: "Product" },
    article:     { type: String, required: true, trim: true }, // product name at purchase time
    qte:         { type: Number, required: true, min: 1 },
    userInfo:    { type: String, trim: true },                 // buyer's name/email snapshot
    userId:      { type: Schema.Types.ObjectId, ref: "User" },
    price:       { type: Number, required: true },
    date:        { type: Date, default: Date.now },
  },
  { timestamps: true }
);

PurchaseSchema.index({ supplierId: 1, date: -1 });

module.exports = mongoose.model("Purchase", PurchaseSchema);
