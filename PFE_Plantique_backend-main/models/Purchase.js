const mongoose = require("mongoose");
const { Schema } = mongoose;

const PurchaseSchema = new Schema(
  {
    sellerId:    { type: Schema.Types.ObjectId, ref: "Account", required: true, index: true },
    productId:   { type: Schema.Types.ObjectId, ref: "Product" },
    article:     { type: String, required: true, trim: true },
    qte:         { type: Number, required: true, min: 1 },
    userInfo:    { type: String, trim: true },
    buyerId:     { type: Schema.Types.ObjectId, ref: "Account" },
    price:          { type: Number, required: true },
    receiptNumber:  { type: String, default: null, index: true },
    date:           { type: Date, default: Date.now },
  },
  { timestamps: true }
);

PurchaseSchema.index({ sellerId: 1, date: -1 });

module.exports = mongoose.model("Purchase", PurchaseSchema);
