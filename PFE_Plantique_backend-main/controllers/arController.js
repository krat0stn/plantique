const path = require("path");
const { cloudinary } = require("../config/cloudinary");
const ArModel = require("../models/Ar");
const mongoose = require("mongoose");
// --- helpers ---
function getExtFromOriginalName(originalname = "") {
  const ext = (originalname.split(".").pop() || "").toLowerCase();
  return ext;
}

function uploadBufferToCloudinary(buffer, options) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(options, (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
    stream.end(buffer);
  });
}

// Optional: Cloudinary catalog search (unchanged)
exports.listModels = async (req, res) => {
  try {
    const folder = process.env.CLD_AR_FOLDER || "plantique/ar_models";
    const result = await cloudinary.search
      .expression(`folder:${folder} AND (format:glb OR format:gltf)`)
      .with_field("context")
      .max_results(100)
      .execute();

    const items = (result.resources || []).map((r) => ({
      _id: r.asset_id,
      name: r.public_id.split("/").pop(),
      plantName: r.context?.custom?.plantName ?? null,
      glbUrl: r.secure_url,
      thumbUrl: null,
      bytes: r.bytes,
      updatedAt: r.created_at,
    }));

    res.json({ data: items });
  } catch (e) {
    res.status(500).json({ errormessage: e.message });
  }
};

// Public DB list
exports.list = async (req, res) => {
  const q = (req.query.q || "").trim();
  const filter = q ? { $text: { $search: q } } : {};
  const items = await ArModel.find(filter).sort({ createdAt: -1 });
  res.json({ data: items });
};

// Public DB get
exports.getById = async (req, res) => {
  const doc = await ArModel.findById(req.params.id);
  if (!doc) return res.status(404).json({ errormessage: "AR model not found" });
  res.json({ data: doc });
};

// Create with memory upload -> Cloudinary
exports.create = async (req, res) => {
  try {
    const { name, plantName, tags } = req.body || {};
    if (!name)
      return res.status(400).json({ errormessage: "name is required" });

    const modelFile = req.files?.model?.[0];
    if (!modelFile)
      return res
        .status(400)
        .json({ errormessage: "3D file is required (field 'model')" });

    const modelExt = getExtFromOriginalName(modelFile.originalname);
    if (!["glb", "gltf"].includes(modelExt)) {
      return res
        .status(400)
        .json({ errormessage: "Model must be .glb or .gltf" });
    }

    const folderModels = process.env.CLD_AR_FOLDER || "plantique/ar_models";
    const folderThumbs = process.env.CLD_AR_THUMBS || "plantique/ar_thumbs";

    // Upload model as raw
    const modelUpload = await uploadBufferToCloudinary(modelFile.buffer, {
      resource_type: "raw",
      folder: folderModels,
      public_id: `ar_${Date.now()}`, // you can use a slug if you prefer
      format: modelExt,
    });

    if (!modelUpload || !modelUpload.public_id || !modelUpload.secure_url) {
      return res
        .status(500)
        .json({ errormessage: "Upload failed: model URL or publicId missing" });
    }

    // Optional thumbnail upload as image
    let thumbUrl;
    let thumbPublicId;
    const thumbFile = req.files?.thumbnail?.[0];
    if (thumbFile) {
      const thumbExt = getExtFromOriginalName(thumbFile.originalname);
      const thumbUpload = await uploadBufferToCloudinary(thumbFile.buffer, {
        resource_type: "image",
        folder: folderThumbs,
        public_id: `ar_thumb_${Date.now()}`,
        format: ["jpg", "jpeg", "png", "webp"].includes(thumbExt)
          ? thumbExt
          : undefined,
        transformation: [{ quality: "auto:good", fetch_format: "auto" }],
      });
      thumbUrl = thumbUpload?.secure_url;
      thumbPublicId = thumbUpload?.public_id;
    }

    const tagsArr =
      typeof tags === "string"
        ? tags
            .split(",")
            .map((t) => t.trim())
            .filter(Boolean)
        : Array.isArray(tags)
        ? tags
        : [];

    const doc = await ArModel.create({
      name: name.trim(),
      plantName: plantName?.trim() || undefined,
      glbUrl: modelUpload.secure_url,
      glbPublicId: modelUpload.public_id,
      thumbUrl: thumbUrl,
      thumbPublicId: thumbPublicId,
      tags: tagsArr,
      author: req.user?._id || req.user?.id || undefined,
    });

    res.status(201).json({ successmessage: "created", data: doc });
  } catch (e) {
    res.status(500).json({ errormessage: e.message });
  }
};

// Update with optional file replacements
exports.update = async (req, res) => {
  try {
    const { name, plantName, tags } = req.body || {};
    const doc = await ArModel.findById(req.params.id);
    if (!doc)
      return res.status(404).json({ errormessage: "AR model not found" });

    if (name !== undefined) doc.name = name.trim();
    if (plantName !== undefined) doc.plantName = plantName.trim();

    if (tags !== undefined) {
      const tagsArr =
        typeof tags === "string"
          ? tags
              .split(",")
              .map((t) => t.trim())
              .filter(Boolean)
          : Array.isArray(tags)
          ? tags
          : [];
      doc.tags = tagsArr;
    }

    const folderModels = process.env.CLD_AR_FOLDER || "plantique/ar_models";
    const folderThumbs = process.env.CLD_AR_THUMBS || "plantique/ar_thumbs";

    // Replace model if provided
    const modelFile = req.files?.model?.[0];
    if (modelFile) {
      const modelExt = getExtFromOriginalName(modelFile.originalname);
      if (!["glb", "gltf"].includes(modelExt)) {
        return res
          .status(400)
          .json({ errormessage: "Model must be .glb or .gltf" });
      }

      // delete old
      if (doc.glbPublicId) {
        try {
          await cloudinary.uploader.destroy(doc.glbPublicId, {
            resource_type: "raw",
          });
        } catch {}
      }

      // upload new
      const modelUpload = await uploadBufferToCloudinary(modelFile.buffer, {
        resource_type: "raw",
        folder: folderModels,
        public_id: `ar_${Date.now()}`,
        format: modelExt,
      });

      if (!modelUpload || !modelUpload.public_id || !modelUpload.secure_url) {
        return res.status(500).json({
          errormessage: "Upload failed: model URL or publicId missing",
        });
      }

      doc.glbUrl = modelUpload.secure_url;
      doc.glbPublicId = modelUpload.public_id;
    }

    // Replace thumbnail if provided
    const thumbFile = req.files?.thumbnail?.[0];
    if (thumbFile) {
      if (doc.thumbPublicId) {
        try {
          await cloudinary.uploader.destroy(doc.thumbPublicId, {
            resource_type: "image",
          });
        } catch {}
      }
      const thumbExt = getExtFromOriginalName(thumbFile.originalname);
      const thumbUpload = await uploadBufferToCloudinary(thumbFile.buffer, {
        resource_type: "image",
        folder: folderThumbs,
        public_id: `ar_thumb_${Date.now()}`,
        format: ["jpg", "jpeg", "png", "webp"].includes(thumbExt)
          ? thumbExt
          : undefined,
        transformation: [{ quality: "auto:good", fetch_format: "auto" }],
      });
      doc.thumbUrl = thumbUpload?.secure_url || null;
      doc.thumbPublicId = thumbUpload?.public_id || null;
    }

    await doc.save();
    res.json({ successmessage: "updated", data: doc });
  } catch (e) {
    res.status(500).json({ errormessage: e.message });
  }
};

exports.list = async (req, res) => {
  try {
    const q = (req.query.q || "").trim();
    const filter = q ? { $text: { $search: q } } : {};
    const items = await ArModel.find(filter).sort({ createdAt: -1 });
    res.json({ data: items });
  } catch (e) {
    res.status(500).json({ errormessage: e.message });
  }
};

exports.getById = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ errormessage: "Invalid id" });
    }
    const doc = await ArModel.findById(req.params.id);
    if (!doc)
      return res.status(404).json({ errormessage: "AR model not found" });
    res.json({ data: doc });
  } catch (e) {
    res.status(500).json({ errormessage: e.message });
  }
};

// Delete model + thumbnail from Cloudinary
exports.remove = async (req, res) => {
  try {
    const doc = await ArModel.findById(req.params.id);
    if (!doc)
      return res.status(404).json({ errormessage: "AR model not found" });

    if (doc.glbPublicId) {
      try {
        await cloudinary.uploader.destroy(doc.glbPublicId, {
          resource_type: "raw",
        });
      } catch {}
    }
    if (doc.thumbPublicId) {
      try {
        await cloudinary.uploader.destroy(doc.thumbPublicId, {
          resource_type: "image",
        });
      } catch {}
    }

    await doc.deleteOne();
    res.json({ successmessage: "deleted", data: doc });
  } catch (e) {
    res.status(500).json({ errormessage: e.message });
  }
};
