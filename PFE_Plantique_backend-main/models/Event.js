const mongoose = require("mongoose");
const { Schema } = mongoose;

const EventSchema = new Schema(
  {
    title:       { type: String, required: true, trim: true },
    description: { type: String, default: "" },
    location:    { type: String, default: "", trim: true },
    price:       { type: Number, default: 0 },
    startDate:   { type: Date, required: true },
    endDate:     { type: Date, required: true },
    imageUrl:    { type: String, trim: true },
    imagePublicId: { type: String, trim: true },
    isActive:    { type: Boolean, default: true },
  },
  { timestamps: true }
);

EventSchema.index({ endDate: -1 });

module.exports = mongoose.model("Event", EventSchema);
