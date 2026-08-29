const mongoose = require("mongoose");
const { Schema } = mongoose;

const saveSchema = new Schema(
  {
    posteId: { type: Schema.Types.ObjectId, ref: "Poste", required: true },
    userId: { type: Schema.Types.ObjectId, ref: "Account", required: true },
  },
  { timestamps: true }
);

saveSchema.index({ posteId: 1, userId: 1 }, { unique: true });
saveSchema.index({ userId: 1, createdAt: -1 });
saveSchema.index({ posteId: 1, createdAt: -1 });

module.exports = mongoose.model("Save", saveSchema);
