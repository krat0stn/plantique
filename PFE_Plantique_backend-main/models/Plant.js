const mongoose = require("mongoose");

const careSchema = new mongoose.Schema(
  {
    watering: String,
    light: String,
    temperature: String,
    humidity: String,
    fertilizer: String,
    misting: String,
    pruning: String,
  },
  { _id: false }
);

const plantCareSchema = new mongoose.Schema(
  {
    slug: {
      type: String,
      index: true,
      trim: true,
      lowercase: true,
    },

    plantName: {
      type: String,
      unique: true,
      index: true,
      required: true,
      trim: true,
    },

    userLevel: String,
    scientificName: String,
    tunisianName: String,
    plantType: String,
    description: String,

    imageUrl: String,
    imagePublicId: String,

    care: careSchema,
  },
  { timestamps: true }
);

plantCareSchema.index({
  plantName: "text",
  scientificName: "text",
  tunisianName: "text",
  plantType: "text",
  description: "text",
});

function slugify(input) {
  return String(input || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)+/g, "");
}

plantCareSchema.pre("validate", function (next) {
  if (!this.slug && this.plantName) {
    this.slug = slugify(this.plantName);
  }
  next();
});

module.exports = mongoose.model("PlantCare", plantCareSchema);
