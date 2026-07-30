const PlantCare = require("../models/Plant");
const { cloudinary } = require("../config/cloudinary");

function toBool(v) {
  return v === true || v === "true" || v === 1 || v === "1";
}

exports.listAdmin = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.min(
      Math.max(parseInt(req.query.limit || "10", 10), 1),
      100,
    );
    const skip = (page - 1) * limit;
    const q = (req.query.q || "").trim();

    let filter = {};
    if (q) filter = { $text: { $search: q } };

    const [items, total] = await Promise.all([
      PlantCare.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
      PlantCare.countDocuments(filter),
    ]);

    return res.status(200).json({
      successmessage: "Plants retrieved (admin)",
      data: items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};

exports.getAdminById = async (req, res) => {
  try {
    const doc = await PlantCare.findById(req.params.id);
    if (!doc) return res.status(404).json({ errormessage: "Plant not found" });
    return res.status(200).json({ successmessage: "Plant fetched", data: doc });
  } catch (err) {
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};

exports.create = async (req, res) => {
  try {
    const {
      plantName,
      userLevel,
      scientificName,
      tunisianName,
      plantType,
      description,
      slug, // optional override
      // care.* can come as flat fields
      "care.watering": watering,
      "care.light": light,
      "care.temperature": temperature,
      "care.humidity": humidity,
      "care.fertilizer": fertilizer,
      "care.misting": misting,
      "care.pruning": pruning,
    } = req.body || {};

    if (!plantName) {
      return res.status(400).json({ errormessage: "plantName is required" });
    }

    const doc = new PlantCare({
      plantName: plantName.trim(),
      userLevel: userLevel?.trim(),
      scientificName: scientificName?.trim(),
      tunisianName: tunisianName?.trim(),
      plantType: plantType?.trim(),
      description: description?.trim(),
      slug: slug?.trim(),
      care: {
        watering,
        light,
        temperature,
        humidity,
        fertilizer,
        misting,
        pruning,
      },
    });

    // Optional image upload via multer (field name "image")
    if (req.file) {
      doc.imageUrl = req.file.path || req.file.secure_url || req.file.url;
      doc.imagePublicId = req.file.filename || req.file.public_id;
    }

    await doc.save();
    return res.status(201).json({ successmessage: "Plant created", data: doc });
  } catch (err) {
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};

exports.update = async (req, res) => {
  try {
    const {
      plantName,
      userLevel,
      scientificName,
      tunisianName,
      plantType,
      description,
      slug,
      "care.watering": watering,
      "care.light": light,
      "care.temperature": temperature,
      "care.humidity": humidity,
      "care.fertilizer": fertilizer,
      "care.misting": misting,
      "care.pruning": pruning,
    } = req.body || {};

    const doc = await PlantCare.findById(req.params.id);
    if (!doc) return res.status(404).json({ errormessage: "Plant not found" });

    if (plantName !== undefined) doc.plantName = plantName.trim();
    if (userLevel !== undefined) doc.userLevel = userLevel.trim();
    if (scientificName !== undefined)
      doc.scientificName = scientificName.trim();
    if (tunisianName !== undefined) doc.tunisianName = tunisianName.trim();
    if (plantType !== undefined) doc.plantType = plantType.trim();
    if (description !== undefined) doc.description = description.trim();
    if (slug !== undefined) doc.slug = slug.trim();

    // Update care fields if provided
    const care = { ...doc.care?.toObject?.(), ...doc.care };
    if (watering !== undefined) care.watering = watering;
    if (light !== undefined) care.light = light;
    if (temperature !== undefined) care.temperature = temperature;
    if (humidity !== undefined) care.humidity = humidity;
    if (fertilizer !== undefined) care.fertilizer = fertilizer;
    if (misting !== undefined) care.misting = misting;
    if (pruning !== undefined) care.pruning = pruning;
    doc.care = care;

    // If new image uploaded, replace and delete old one
    if (req.file) {
      if (doc.imagePublicId) {
        try {
          await cloudinary.uploader.destroy(doc.imagePublicId, {
            resource_type: "image",
          });
        } catch {}
      }
      doc.imageUrl = req.file.path || req.file.secure_url || req.file.url;
      doc.imagePublicId = req.file.filename || req.file.public_id;
    }

    await doc.save();
    return res.status(200).json({ successmessage: "Plant updated", data: doc });
  } catch (err) {
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};

exports.remove = async (req, res) => {
  try {
    const doc = await PlantCare.findById(req.params.id);
    if (!doc) return res.status(404).json({ errormessage: "Plant not found" });

    if (doc.imagePublicId) {
      try {
        await cloudinary.uploader.destroy(doc.imagePublicId, {
          resource_type: "image",
        });
      } catch {}
    }
    await doc.deleteOne();
    return res.status(200).json({ successmessage: "Plant deleted", data: doc });
  } catch (err) {
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};

// Optional: delete only the image
exports.removeImage = async (req, res) => {
  try {
    const doc = await PlantCare.findById(req.params.id);
    if (!doc) return res.status(404).json({ errormessage: "Plant not found" });

    if (doc.imagePublicId) {
      try {
        await cloudinary.uploader.destroy(doc.imagePublicId, {
          resource_type: "image",
        });
      } catch {}
    }
    doc.imageUrl = null;
    doc.imagePublicId = null;
    await doc.save();

    return res.status(200).json({ successmessage: "Image removed", data: doc });
  } catch (err) {
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};
