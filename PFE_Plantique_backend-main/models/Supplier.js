const mongoose = require("mongoose");
const { Schema } = mongoose;

const SupplierSchema = new Schema(
  {
    firstName:    { type: String, required: true, trim: true },
    lastName:     { type: String, required: true, trim: true },
    shopName:     { type: String, required: true, trim: true, index: true },
    shopType:     { type: String, trim: true },
    email:        { type: String, trim: true, lowercase: true },
    password:     { type: String, select: false },
    phone:        { type: String, trim: true },
    location:     { type: String, trim: true },
    bio:          { type: String, default: "" },
    logoUrl:      { type: String, trim: true },
    logoPublicId: { type: String, trim: true },
    isActive:     { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Supplier", SupplierSchema);