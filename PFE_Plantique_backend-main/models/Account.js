const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const AccountSchema = new Schema(
  {
    // ── Identity (common) ────────────────────────────────────────────────
    email: {
      type: String,
      required: [true, "Email is required."],
      trim: true,
      unique: true,
      lowercase: true,
      maxlength: [100, "Email cannot exceed 100 characters."],
    },
    password: {
      type: String,
      trim: true,
      select: false,
      default: null,
    },
    role: {
      type: String,
      enum: ["Admin", "User", "Supplier"],
      required: true,
      default: "User",
    },
    picture: {
      type: String,
    },
    status: {
      type: String,
      enum: ["Active", "Inactive"],
      default: "Active",
    },

    // ── User-specific fields ─────────────────────────────────────────────
    username: {
      type: String,
      trim: true,
      maxlength: [40, "Username cannot exceed 40 characters."],
    },
    resetCode: {
      type: String,
      default: null,
    },
    resetCodeExpires: {
      type: Date,
      default: null,
    },

    // ── Supplier-specific fields ─────────────────────────────────────────
    firstName: {
      type: String,
      trim: true,
    },
    lastName: {
      type: String,
      trim: true,
    },
    shopName: {
      type: String,
      trim: true,
      index: { sparse: true },
    },
    shopType: {
      type: String,
      trim: true,
    },
    phone: {
      type: String,
      trim: true,
    },
    location: {
      type: String,
      trim: true,
    },
    bio: {
      type: String,
      default: "",
    },
    logoUrl: {
      type: String,
      trim: true,
    },
    logoPublicId: {
      type: String,
      trim: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    subscriptionStart: {
      type: Date,
      default: null,
    },
    subscriptionEnd: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true, versionKey: false }
);

AccountSchema.index({ role: 1, createdAt: -1 });

module.exports = mongoose.model("Account", AccountSchema);
