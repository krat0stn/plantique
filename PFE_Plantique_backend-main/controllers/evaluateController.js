const ArModel = require("../models/Ar");
const axios = require("axios");

const OPEN_METEO = "https://api.open-meteo.com/v1/forecast";

exports.evaluate = async (req, res) => {
  try {
    const { plantId, lat, lon } = req.body;

    if (!plantId || lat == null || lon == null) {
      return res
        .status(400)
        .json({ error: "plantId, lat and lon are required" });
    }

    const plant = await ArModel.findById(plantId);
    if (!plant) return res.status(404).json({ error: "Plant not found" });

    // Fetch current temperature + humidity from Open-Meteo (free, no key)
    const weather = await axios.get(OPEN_METEO, {
      params: {
        latitude: lat,
        longitude: lon,
        current: "temperature_2m,relative_humidity_2m",
      },
    });

    const { temperature_2m: temp, relative_humidity_2m: humidity } =
      weather.data.current;

    // Compare — if the plant has no range set, mark ok as null (unknown)
    const tempOk =
      plant.tempMin != null && plant.tempMax != null
        ? temp >= plant.tempMin && temp <= plant.tempMax
        : null;

    const humOk =
      plant.humidityMin != null && plant.humidityMax != null
        ? humidity >= plant.humidityMin && humidity <= plant.humidityMax
        : null;

    // "perfect" only if both checks pass (or are unknown)
    const verdict =
      tempOk === false || humOk === false ? "not_ideal" : "perfect";

    return res.json({
      temperature: {
        value: temp,
        ok: tempOk,
        ideal:
          plant.tempMin != null ? [plant.tempMin, plant.tempMax] : null,
      },
      humidity: {
        value: humidity,
        ok: humOk,
        ideal:
          plant.humidityMin != null
            ? [plant.humidityMin, plant.humidityMax]
            : null,
      },
      verdict,
    });
  } catch (err) {
    console.error("evaluate error:", err.message);
    res.status(500).json({ error: "Environment check failed" });
  }
};
