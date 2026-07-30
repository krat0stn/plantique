// services/llmDiseaseService.js
const axios = require("axios");

const LLM_BASE_URL = process.env.LLM_BASE_URL || "http://localhost:8000";

async function getDiseaseRecommendationFromLLM(disease, language = "en") {
  try {
    const res = await axios.post(
      `${LLM_BASE_URL}/llm/disease/recommendation`,
      { disease, language },
      { timeout: 60000 }, // 60 seconds — LLM takes time
    );
    return res.data;
  } catch (err) {
    console.error(
      "Error calling LLM disease API:",
      err.response?.data || err.message,
    );
    throw new Error("LLM_SERVICE_ERROR");
  }
}

module.exports = { getDiseaseRecommendationFromLLM };
