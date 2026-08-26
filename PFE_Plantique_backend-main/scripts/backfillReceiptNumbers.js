/**
 * Backfill receipt numbers for existing purchases.
 * Run once: node scripts/backfillReceiptNumbers.js
 */
require("dotenv").config();
const mongoose = require("mongoose");
const Purchase = require("../models/Purchase");

async function backfill() {
  const mongoUri = process.env.MONGO_URI;
  if (!mongoUri) {
    console.error("MONGO_URI is not set in environment.");
    process.exit(1);
  }

  await mongoose.connect(mongoUri);
  console.log("Connected to MongoDB");

  // Get distinct supplier IDs that have purchases without receiptNumber
  const supplierIds = await Purchase.distinct("supplierId", {
    receiptNumber: null,
  });

  console.log(`Found ${supplierIds.length} supplier(s) with purchases to backfill`);

  for (const supplierId of supplierIds) {
    const purchases = await Purchase.find({ supplierId })
      .sort({ date: 1, createdAt: 1 })
      .lean();

    for (let i = 0; i < purchases.length; i++) {
      if (!purchases[i].receiptNumber) {
        const receiptNumber = `RE${String(i + 1).padStart(2, "0")}`;
        await Purchase.updateOne(
          { _id: purchases[i]._id },
          { $set: { receiptNumber } }
        );
        console.log(`  ${purchases[i]._id} -> ${receiptNumber}`);
      }
    }
  }

  console.log("Backfill complete");
  await mongoose.disconnect();
}

backfill().catch((err) => {
  console.error("Backfill failed:", err);
  process.exit(1);
});
