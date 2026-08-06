const express = require("express");
const router = express.Router();
const PlantCare = require("../models/Plant");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

function extractTypes(plantType) {
  const raw = String(plantType || "");
  return raw
    .split(/[•,;/]/)
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

// ---------- GET /api/plant-care/types ----------
router.get("/types", async (req, res) => {
  try {
    const plants = await PlantCare.find().select("plantType");
    const typeMap = new Map();

    plants.forEach((p) => {
      const types = extractTypes(p.plantType);
      types.forEach((t) => {
        const lower = t.toLowerCase();
        if (!typeMap.has(lower)) {
          const pretty = t.charAt(0).toUpperCase() + t.slice(1);
          typeMap.set(lower, pretty);
        }
      });
    });

    const allTypes = Array.from(typeMap.values()).sort((a, b) =>
      a.toLowerCase().localeCompare(b.toLowerCase()),
    );

    res.json({ ok: true, data: allTypes });
  } catch (err) {
    console.error("Error fetching plant types:", err);
    res.status(500).json({ ok: false, error: "Server error" });
  }
});

// ---------- GET /api/plant-care?type=SomeType ----------
router.get("/", async (req, res) => {
  try {
    const { type } = req.query;

    const plants = await PlantCare.find()
      .select("slug plantName scientificName tunisianName plantType description imageUrl care")
      .sort({ plantName: 1 });

    let filtered = plants;

    if (type) {
      const requested = String(type).toLowerCase().trim();
      filtered = plants.filter((p) => {
        const types = extractTypes(p.plantType).map((t) => t.toLowerCase());
        return types.includes(requested);
      });
    }

    res.json({ ok: true, data: filtered });
  } catch (err) {
    console.error("Error fetching plants:", err);
    res.status(500).json({ ok: false, error: "Server error" });
  }
});

// ---------- GET /api/plant-care/:slug ----------
router.get("/:slug", async (req, res) => {
  try {
    const rawSlug = req.params.slug;
    const norm = String(rawSlug).trim().toLowerCase().replace(/_/g, "-");
    const plant = await PlantCare.findOne({ slug: norm });

    if (!plant) {
      return res.status(404).json({ ok: false, error: `Plant not found for '${rawSlug}'` });
    }

    res.json({ ok: true, data: plant });
  } catch (err) {
    console.error("Error fetching plant care by slug:", err);
    res.status(500).json({ ok: false, error: "Server error" });
  }
});

// ---------- POST /api/plant-care (Admin only) ----------
const { cloudinary } = require("../config/cloudinary");

router.post("/", verifyToken, isAdmin, async (req, res) => {
  try {
    const body = req.body || {};
    
    const plantData = {
      plantName: body.plantName,
      scientificName: body.scientificName,
      tunisianName: body.tunisianName,
      description: body.description,
      plantType: body.plantType,
      slug: body.slug,
    };

    // Upload base64 to Cloudinary
    if (body.imageBase64) {
      const uploadResult = await cloudinary.uploader.upload(
        `data:image/jpeg;base64,${body.imageBase64}`,
        { folder: "plantique/plants" }
      );
      plantData.imageUrl = uploadResult.secure_url;
    }

    const plant = await PlantCare.create(plantData);
    res.status(201).json({ ok: true, data: plant });
  } catch (err) {
    console.error("Error creating plant:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ---------- PUT /api/plant-care/:id (Admin only) ----------
router.put("/:id", verifyToken, isAdmin, async (req, res) => {
  try {
    const plant = await PlantCare.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!plant) {
      return res.status(404).json({ ok: false, error: "Plant not found" });
    }
    res.json({ ok: true, data: plant });
  } catch (err) {
    console.error("Error updating plant:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ---------- DELETE /api/plant-care/:id (Admin only) ----------
router.delete("/:id", verifyToken, isAdmin, async (req, res) => {
  try {
    const plant = await PlantCare.findByIdAndDelete(req.params.id);
    if (!plant) {
      return res.status(404).json({ ok: false, error: "Plant not found" });
    }
    res.json({ ok: true, message: "Plant deleted successfully" });
  } catch (err) {
    console.error("Error deleting plant:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

module.exports = router;