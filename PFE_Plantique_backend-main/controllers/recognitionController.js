const axios = require("axios");
const FormData = require("form-data");
const { cloudinary } = require("../config/cloudinary");
const Identification = require("../models/Identification");

const PYTHON_RECO_FILE_URL = process.env.FASTAPI_BASE_URL
  ? `${process.env.FASTAPI_BASE_URL}/recognition/predict`
  : "http://127.0.0.1:8000/recognition/predict";

exports.identifyFromFile = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ ok: false, error: "Image is required" });
    }

    // 1) Envoyer l'image à FastAPI
    const formData = new FormData();
    formData.append("file", req.file.buffer, {
      filename: req.file.originalname || "image.jpg",
      contentType: req.file.mimetype || "image/jpeg",
    });

    const fastApiResp = await axios.post(PYTHON_RECO_FILE_URL, formData, {
      headers: formData.getHeaders(),
      maxBodyLength: Infinity,
      maxContentLength: Infinity,
    });

    const prediction = fastApiResp.data;

    // 2) Extraire plantName + confidence
    const plantName =
      prediction.top_label ||
      prediction.label ||
      prediction.class_name ||
      prediction.plantName ||
      "unknown";

    let confidence = null;
    if (typeof prediction.top_score === "number") {
      confidence = prediction.top_score;
    } else if (typeof prediction.confidence === "number") {
      confidence = prediction.confidence;
    } else if (typeof prediction.prob === "number") {
      confidence = prediction.prob;
    } else if (typeof prediction.score === "number") {
      confidence = prediction.score;
    }

    if (confidence === null) {
      console.warn("No confidence field found in prediction:", prediction);
    }

    // 3) Uploader l'image sur Cloudinary pour pouvoir l'afficher dans la Library
    let imageUrl = null;
    if (cloudinary) {
      imageUrl = await new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
          {
            folder: "plantique/identifications",
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

    // 4) Sauvegarder dans Mongo (historique complet)
    let identificationDoc = null;
    if (req.user && req.user._id) {
      identificationDoc = await Identification.create({
        user: req.user._id,
        plantName,
        confidence,
        imageUrl, // 👈 maintenant non nul
        // savedToLibrary: false (par défaut)
      });
    }

    // 5) Réponse à Flutter
    return res.status(200).json({
      ok: true,
      source: "fastapi-recognition-file",
      prediction,
      identification: identificationDoc,
    });
  } catch (err) {
    console.error("Recognition (file) error:", err.message);
    if (err.response) {
      console.error("FastAPI response:", err.response.data);
    }
    return res.status(500).json({
      ok: false,
      error: "Error while identifying plant (file)",
      details: err.message,
    });
  }
};
