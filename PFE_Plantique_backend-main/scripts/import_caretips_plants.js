require("dotenv").config();
const path = require("path");
const fs = require("fs");
const csv = require("csv-parser");
const mongoose = require("mongoose");
const PlantCare = require("../models/Plant");

const MONGO_URI = process.env.MONGO_URI;

async function connectDB() {
  await mongoose.connect(MONGO_URI);
  console.log(" Connected to MongoDB");
}

async function importCSV() {
  await connectDB();

  const filePath = path.join(__dirname, "..", "data", "caretips_plants.csv");
  const rows = [];

  fs.createReadStream(filePath)
    .pipe(csv())
    .on("data", (row) => {
      rows.push(row);
    })
    .on("end", async () => {
      console.log(` ${rows.length} lignes lues depuis caretips_plants.csv`);

      for (const row of rows) {
        try {
          const plantName = row["plant_name"];
          const userLevel = row["user_level"];
          const scientificName = row["scientific_name"];
          const tunisianName = row["tunisian_name"];
          const plantType = row["plant_type"];
          const description = row["description"];

          const care = {
            watering: row["watering"],
            light: row["light"],
            temperature: row["temperature"],
            humidity: row["humidity"],
            fertilizer: row["fertilizer"],
            misting: row["misting"],
            pruning: row["pruning"],
          };

          await PlantCare.findOneAndUpdate(
            { plantName },
            {
              plantName,
              userLevel,
              scientificName,
              tunisianName,
              plantType,
              description,
              care,
            },
            { upsert: true, new: true, setDefaultsOnInsert: true },
          );

          console.log(`Upsert caretips: ${plantName}`);
        } catch (err) {
          console.error("Error on row:", row, err.message);
        }
      }

      console.log(" Import terminé");
      mongoose.connection.close();
    });
}

importCSV().catch((err) => {
  console.error(" Fatal error:", err);
  mongoose.connection.close();
});
