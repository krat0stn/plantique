const mongoose = require("mongoose");
const { Schema } = mongoose;

const ArModelSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    plantName: { type: String, trim: true },
    glbUrl: { type: String, required: true, trim: true },
    glbPublicId: { type: String, required: true, trim: true },
    thumbUrl: { type: String, trim: true },
    thumbPublicId: { type: String, trim: true },
    tags: [{ type: String, trim: true }],
    author: { type: Schema.Types.ObjectId, ref: "User" },

    // Real-world scale range the user can set in AR (meters)
    scaleMin: { type: Number },
    scaleMax: { type: Number },

    // Ideal environment ranges for this plant
    tempMin:     { type: Number },
    tempMax:     { type: Number },
    humidityMin: { type: Number },
    humidityMax: { type: Number },
  },
  { timestamps: true }
);

ArModelSchema.index({ createdAt: -1 });
ArModelSchema.index({ name: "text", plantName: "text" });

module.exports = mongoose.model("ArModel", ArModelSchema);
