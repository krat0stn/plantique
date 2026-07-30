// scripts/importCaretipsFromCsv.js
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const csv = require("csv-parser");
const mongoose = require("mongoose");
const PlantCare = require("../models/Plant");

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) throw new Error("MONGO_URI is not defined in .env");

const CSV_PATH = path.join(
  __dirname,
  "..",
  "data",
  "caretips_plants_updated.csv",
);

// "aloe_vera" or "aloe-vera" → "Aloe Vera"
function normalizeName(raw) {
  return raw
    .trim()
    .replace(/[_-]/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

async function processRow(row) {
  const rawName = row.plant_name?.trim();
  if (!rawName) {
    console.warn("Row without plant_name, skipping:", row);
    return;
  }

  const plantName = normalizeName(rawName);

  // find the correct Title Case version
  let plant = await PlantCare.findOne({ plantName });

  // also check if an old lowercase version exists with an image we can rescue
  const oldPlant = await PlantCare.findOne({ plantName: rawName });

  if (!plant) {
    plant = new PlantCare({ plantName });
  }

  // rescue imageUrl from old lowercase doc if current one has none
  if (!plant.imageUrl && oldPlant?.imageUrl) {
    plant.imageUrl = oldPlant.imageUrl;
    plant.imagePublicId = oldPlant.imagePublicId;
    console.log(`  Rescued image from old entry "${rawName}"`);
  }

  // fill in care data from CSV
  plant.scientificName = row.scientific_name || plant.scientificName;
  plant.tunisianName = row.tunisian_name || plant.tunisianName;
  plant.plantType = row.plant_type || plant.plantType;
  plant.description = row.description || plant.description;
  plant.userLevel = row.user_level || plant.userLevel;

  plant.care = {
    watering: row.watering || plant.care?.watering,
    light: row.light || plant.care?.light,
    temperature: row.temperature || plant.care?.temperature,
    humidity: row.humidity || plant.care?.humidity,
    fertilizer: row.fertilizer || plant.care?.fertilizer,
    misting: row.misting || plant.care?.misting,
    pruning: row.pruning || plant.care?.pruning,
  };

  await plant.save();

  // delete old lowercase duplicate now that we've rescued its data
  if (oldPlant && oldPlant._id.toString() !== plant._id.toString()) {
    await PlantCare.deleteOne({ _id: oldPlant._id });
    console.log(`  Deleted old duplicate: "${rawName}"`);
  }

  console.log("Upserted:", plantName);
}

async function main() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log("Connected to MongoDB Atlas");

    if (!fs.existsSync(CSV_PATH)) {
      console.error("CSV file not found at:", CSV_PATH);
      process.exit(1);
    }

    console.log("Reading CSV:", CSV_PATH);
    const rows = [];

    await new Promise((resolve, reject) => {
      fs.createReadStream(CSV_PATH)
        .pipe(csv())
        .on("data", (data) => rows.push(data))
        .on("end", resolve)
        .on("error", reject);
    });

    console.log("Rows found in CSV:", rows.length);

    for (const row of rows) {
      try {
        await processRow(row);
      } catch (err) {
        console.error("Error processing row:", row.plant_name, err.message);
      }
    }

    console.log("---- IMPORT DONE ----");
    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error("Fatal error:", err);
    process.exit(1);
  }
}

main();
