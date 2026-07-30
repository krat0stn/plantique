// controllers/diagnosisController.js
const axios = require("axios");
const FormData = require("form-data");
const { cloudinary } = require("../config/cloudinary");
const Diagnosis = require("../models/Diagnosis");

const PYTHON_DIAGNOSE_URL = process.env.FASTAPI_DIAGNOSIS_URL
  ? `${process.env.FASTAPI_DIAGNOSIS_URL}/api/diagnosis/predict`
  : "http://127.0.0.1:8002/api/diagnosis/predict";

exports.diagnosePlant = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ ok: false, error: "Image is required" });
    }

    const formData = new FormData();
    formData.append("file", req.file.buffer, {
      filename: req.file.originalname || "image.jpg",
      contentType: req.file.mimetype || "image/jpeg",
    });

    const response = await axios.post(PYTHON_DIAGNOSE_URL, formData, {
      headers: formData.getHeaders(),
      maxBodyLength: Infinity,
      maxContentLength: Infinity,
    });

    const prediction = response.data;

    const diseaseName =
      prediction.predicted_class ||
      prediction.label ||
      prediction.class_name ||
      prediction.diseaseName ||
      "unknown";

    let confidence = null;

    if (typeof prediction.confidence === "number") {
      confidence = prediction.confidence;
    } else if (typeof prediction.prob === "number") {
      confidence = prediction.prob;
    } else if (typeof prediction.score === "number") {
      confidence = prediction.score;
    }

    if (confidence === null) {
      console.warn(
        "No confidence field found in diagnosis prediction:",
        prediction,
      );
    }

    let imageUrl = null;
    if (cloudinary) {
      imageUrl = await new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
          {
            folder: "plantique/diagnosis",
            resource_type: "image",
          },
          (error, result) => {
            if (error) return reject(error);
            resolve(result.secure_url);
          },
        );
        uploadStream.end(req.file.buffer);
      });
    }

    let diagnosisDoc = null;
    if (req.user && req.user._id) {
      diagnosisDoc = await Diagnosis.create({
        user: req.user._id,
        diseaseName,
        confidence,
        imageUrl,
      });
    }

    return res.status(200).json({
      ok: true,
      source: "fastapi-diagnosis",
      prediction,
      diagnosis: diagnosisDoc,
    });
  } catch (err) {
    console.error("Diagnosis error:", err.message);
    if (err.response) {
      console.error("FastAPI response:", err.response.data);
    }
    return res.status(500).json({
      ok: false,
      error: "Error while diagnosing plant",
      details: err.message,
    });
  }
};
exports.deleteDiagnosis = async (req, res) => {
  try {
    const { id } = req.params;

    if (!req.user || !req.user._id) {
      return res
        .status(401)
        .json({ ok: false, error: "Unauthorized: user not found in token" });
    }

    const doc = await Diagnosis.findOneAndDelete({
      _id: id,
      user: req.user._id,
    });

    if (!doc) {
      return res.status(404).json({ ok: false, error: "Diagnosis not found" });
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error("Error deleting diagnosis:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while deleting diagnosis",
    });
  }
};

// 🔹 NOUVEAU : GET /api/diagnosis  => historique de l'utilisateur connecté
exports.getMyDiagnoses = async (req, res) => {
  try {
    if (!req.user || !req.user._id) {
      return res
        .status(401)
        .json({ ok: false, error: "Unauthorized: user not found in token" });
    }

    const docs = await Diagnosis.find({ user: req.user._id })
      .sort({ createdAt: -1 })
      .select("diseaseName confidence imageUrl createdAt");

    return res.status(200).json({
      ok: true,
      data: docs,
    });
  } catch (err) {
    console.error("Error fetching diagnosis history:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while fetching diagnosis history",
    });
  }
};
