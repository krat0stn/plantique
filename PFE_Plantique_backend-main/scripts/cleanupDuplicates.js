// scripts/cleanupDuplicates.js
require("dotenv").config();
const mongoose = require("mongoose");
const Plant = require("../models/Plant");

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) throw new Error("MONGO_URI is not defined in .env");

async function main() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log("Connected to MongoDB Atlas");

    const plants = await Plant.find({});
    console.log("Total plants in DB:", plants.length);

    let deleted = 0;

    for (const plant of plants) {
      const name = plant.plantName;

      // old entries are fully lowercase (e.g. "basil", "mint", "rose")
      if (name === name.toLowerCase()) {
        // check if a proper Title Case version exists
        const correctName = name.replace(/\b\w/g, (c) => c.toUpperCase());
        const correctExists = await Plant.findOne({ plantName: correctName });

        if (correctExists) {
          await Plant.deleteOne({ _id: plant._id });
          console.log(`Deleted: "${name}" → kept "${correctName}"`);
          deleted++;
        } else {
          console.log(
            `Skipped: "${name}" — no Title Case version found, keeping it`,
          );
        }
      }
    }

    console.log("\n---- SUMMARY ----");
    console.log("Deleted:", deleted);
    console.log("Remaining:", plants.length - deleted);
    console.log("Done.");

    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error("Fatal error:", err);
    process.exit(1);
  }
}

main();
