const PlantCare = require("../models/Plant");
const { cloudinary } = require("../config/cloudinary");

function toBool(v) {
  return v === true || v === "true" || v === 1 || v === "1";
}

// ── helpers ──────────────────────────────────────────────────────
function slugify(text) {
  return String(text || "")
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

async function generateUniqueSlug(baseSlug) {
  let slug = baseSlug;
  let counter = 1;
  while (await PlantCare.exists({ slug })) {
    slug = `${baseSlug}-${counter}`;
    counter++;
  }
  return slug;
}
// ────────────────────────────────────────────────────────────────

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
      slug,
      "care.watering": watering,
      "care.light": light,
      "care.temperature": temperature,
      "care.humidity": humidity,
      "care.fertilizer": fertilizer,
      "care.misting": misting,
      "care.pruning": pruning,
    } = req.body || {};

    if (!plantName || !plantName.trim()) {
      return res.status(400).json({ errormessage: "plantName is required" });
    }

    // Build care object ONLY from fields that were actually sent
    const carePayload = {};
    if (watering !== undefined) carePayload.watering = watering;
    if (light !== undefined) carePayload.light = light;
    if (temperature !== undefined) carePayload.temperature = temperature;
    if (humidity !== undefined) carePayload.humidity = humidity;
    if (fertilizer !== undefined) carePayload.fertilizer = fertilizer;
    if (misting !== undefined) carePayload.misting = misting;
    if (pruning !== undefined) carePayload.pruning = pruning;

    // Auto-generate slug if missing; handle duplicates
    let finalSlug = slug?.trim();
    if (!finalSlug) {
      finalSlug = await generateUniqueSlug(slugify(plantName));
    } else if (await PlantCare.exists({ slug: finalSlug })) {
      finalSlug = await generateUniqueSlug(finalSlug);
    }

    const doc = new PlantCare({
      plantName: plantName.trim(),
      userLevel: userLevel?.trim(),
      scientificName: scientificName?.trim(),
      tunisianName: tunisianName?.trim(),
      plantType: plantType?.trim(),
      description: description?.trim(),
      slug: finalSlug,
      ...(Object.keys(carePayload).length > 0 && { care: carePayload }),
    });

    if (req.file) {
      doc.imageUrl = req.file.path || req.file.secure_url || req.file.url;
      doc.imagePublicId = req.file.filename || req.file.public_id;
    }

    await doc.save();
    return res.status(201).json({ successmessage: "Plant created", data: doc });
  } catch (err) {
    console.error("CREATE PLANT ERROR:", err);
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

    // ── Robust care merge ──
    const careUpdates = {};
    if (watering !== undefined) careUpdates.watering = watering;
    if (light !== undefined) careUpdates.light = light;
    if (temperature !== undefined) careUpdates.temperature = temperature;
    if (humidity !== undefined) careUpdates.humidity = humidity;
    if (fertilizer !== undefined) careUpdates.fertilizer = fertilizer;
    if (misting !== undefined) careUpdates.misting = misting;
    if (pruning !== undefined) careUpdates.pruning = pruning;

    if (Object.keys(careUpdates).length > 0) {
      const existingCare =
        doc.care && typeof doc.care.toObject === "function"
          ? doc.care.toObject()
          : doc.care || {};
      doc.care = { ...existingCare, ...careUpdates };
    }

    // ── Image replacement (delete old ONLY after new is confirmed) ──
    if (req.file) {
      const oldPublicId = doc.imagePublicId;
      doc.imageUrl = req.file.path || req.file.secure_url || req.file.url;
      doc.imagePublicId = req.file.filename || req.file.public_id;

      await doc.save();

      if (oldPublicId && oldPublicId !== doc.imagePublicId) {
        try {
          await cloudinary.uploader.destroy(oldPublicId, {
            resource_type: "image",
          });
        } catch (cloudErr) {
          console.warn("Failed to delete old Cloudinary image:", cloudErr.message);
        }
      }
      return res
        .status(200)
        .json({ successmessage: "Plant updated", data: doc });
    }

    await doc.save();
    return res.status(200).json({ successmessage: "Plant updated", data: doc });
  } catch (err) {
    console.error("UPDATE PLANT ERROR:", err);
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