const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const UserSchema = new Schema(
  {
    username: {
      type: String,
      required: [true, "Le champ Nom de l utilisateur est requis."],
      trim: true,
      maxlength: [20, "Le nom ne peut pas dépasser 20 caractères."],
    },
    email: {
      type: String,
      required: [true, "Le champ Email est requis."],
      trim: true,
      unique: true,
      maxlength: [30, "L'email ne peut pas dépasser 30 caractères."],
    },
    password: {
      type: String,
      trim: true,
      default: null,
    },
    picture: {
      type: String,
    },
    role: {
      type: String,
      enum: ["Admin", "User"],
      default: "User",
    },
    status: {
      type: String,
      enum: ["Active", "Inactive"],
      default: "Active",
    },

    resetCode: {
      type: String,
      default: null,
    },
    resetCodeExpires: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true, versionKey: false }
);

module.exports = mongoose.model("User", UserSchema);
