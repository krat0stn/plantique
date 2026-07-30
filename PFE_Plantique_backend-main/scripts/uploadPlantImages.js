// scripts/uploadPlantImages.js
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const mongoose = require("mongoose");
const cloudinary = require("cloudinary").v2;
const Plant = require("../models/Plant");

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) throw new Error("MONGO_URI is not defined in .env");

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const IMAGES_DIR = path.join(__dirname, "..", "plant_images");
const IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp"];

// "aloe_vera" or "aloe-vera" → "Aloe Vera"
function normalizeName(raw) {
  return raw
    .trim()
    .replace(/[_-]/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function isOldName(plantName) {
  // old names have underscores or hyphens e.g. "aloe_vera", "aloe-vera"
  return /[_-]/.test(plantName);
}

function findLocalImage(slug) {
  const variants = [slug, slug.replace(/-/g, "_"), slug.replace(/_/g, "-")];
  for (const variant of variants) {
    for (const ext of IMAGE_EXTENSIONS) {
      const filePath = path.join(IMAGES_DIR, variant + ext);
      if (fs.existsSync(filePath)) return filePath;
    }
  }
  return null;
}

async function main() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log("Connected to MongoDB Atlas");

    const plants = await Plant.find({});
    console.log("Plants found in DB:", plants.length);

    // ---- STEP 1: Delete old underscore/hyphen named duplicates ----
    console.log("\n---- Cleaning up old duplicate entries ----");
    let deleted = 0;
    for (const plant of plants) {
      if (isOldName(plant.plantName)) {
        const correctName = normalizeName(plant.plantName);
        const correctExists = await Plant.findOne({ plantName: correctName });
        if (correctExists) {
          // correct version exists → safe to delete the old one
          await Plant.deleteOne({ _id: plant._id });
          console.log(
            `Deleted duplicate: "${plant.plantName}" (kept "${correctName}")`,
          );
          deleted++;
        } else {
          // correct version doesn't exist yet → rename instead of delete
          plant.plantName = correctName;
          await plant.save();
          console.log(`Renamed: "${plant.plantName}" → "${correctName}"`);
        }
      }
    }
    console.log(`Deleted ${deleted} old duplicate entries\n`);

    // ---- STEP 2: Upload images for plants that don't have one yet ----
    console.log("---- Uploading missing images ----");
    const freshPlants = await Plant.find({});
    let updated = 0;
    let skippedHasImage = 0;
    let skippedNoFile = 0;

    for (const plant of freshPlants) {
      try {
        if (plant.imageUrl) {
          skippedHasImage++;
          console.log("Skip (already has image):", plant.plantName);
          continue;
        }

        const slug = plant.slug;
        if (!slug) {
          console.warn("No slug for plant:", plant.plantName);
          skippedNoFile++;
          continue;
        }

        const localPath = findLocalImage(slug);
        if (!localPath) {
          skippedNoFile++;
          console.warn(
            "No image file found for:",
            plant.plantName,
            "| slug:",
            slug,
          );
          continue;
        }

        console.log("Uploading:", plant.plantName, "from", localPath);

        const uploadRes = await cloudinary.uploader.upload(localPath, {
          folder: "plantique/plants",
          public_id: slug,
        });

        plant.imageUrl = uploadRes.secure_url;
        plant.imagePublicId = uploadRes.public_id;
        await plant.save();

        updated++;
        console.log("Saved imageUrl for:", plant.plantName);
      } catch (err) {
        console.error("Error processing plant:", plant.plantName, err.message);
      }
    }

    console.log("\n---- SUMMARY ----");
    console.log("Duplicates deleted:", deleted);
    console.log("Images uploaded:", updated);
    console.log("Skipped (had image):", skippedHasImage);
    console.log("Skipped (no file):", skippedNoFile);

    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error("Fatal error:", err);
    process.exit(1);
  }
}

main();
