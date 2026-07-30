const Recommendation = require("../models/Recommendation");
const {
  getDiseaseRecommendationFromLLM,
} = require("../services/llmDiseaseService");

exports.getDiseaseRecommendation = async (req, res) => {
  try {
    const { disease } = req.params;
    const { language } = req.body || {};

    if (!disease) {
      return res
        .status(400)
        .json({ ok: false, error: "Disease is required in URL params" });
    }

    const lang = language || "en";
    const diseaseKey = disease.toLowerCase().trim();

    if (diseaseKey === "unknown") {
      return res.status(400).json({
        ok: false,
        error: "Cannot generate recommendation for unknown disease",
      });
    }

    // check cache Mongo
    let recommendation = await Recommendation.findOne({ disease: diseaseKey });

    if (recommendation) {
      return res.json({
        ok: true,
        fromCache: true,
        disease: recommendation.disease,
        language: recommendation.language,
        symptoms: recommendation.symptoms,
        prevention: recommendation.prevention,
        recommendations: recommendation.recommendations,
        treatment: recommendation.treatment,
        rawText: recommendation.rawText,
      });
    }

    //  call LLM FastAPI
    const llmData = await getDiseaseRecommendationFromLLM(diseaseKey, lang);

    //  save in Mongo
    try {
      recommendation = await Recommendation.create({
        disease: diseaseKey,
        language: lang,
        symptoms: llmData.symptoms,
        prevention: llmData.prevention,
        recommendations: llmData.recommendations,
        treatment: llmData.treatment,
        rawText: llmData.raw_text || llmData.rawText || "",
      });
    } catch (err) {
      if (err.code === 11000) {
        recommendation = await Recommendation.findOne({ disease: diseaseKey });
      } else {
        console.error("Error saving recommendation:", err);
        throw err;
      }
    }

    return res.json({
      ok: true,
      fromCache: false,
      disease: recommendation.disease,
      language: recommendation.language,
      symptoms: recommendation.symptoms,
      prevention: recommendation.prevention,
      recommendations: recommendation.recommendations,
      treatment: recommendation.treatment,
      rawText: recommendation.rawText,
    });
  } catch (err) {
    console.error("getDiseaseRecommendation error:", err.message);
    return res
      .status(500)
      .json({ ok: false, error: "Failed to get disease recommendation" });
  }
};
