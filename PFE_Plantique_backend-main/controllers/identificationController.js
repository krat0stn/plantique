const Identification = require("../models/Identification");

exports.listMyLibrary = async (req, res) => {
  try {
    const userId = req.user._id;

    const items = await Identification.find({
      user: userId,
      savedToLibrary: true,
    })
      .sort({ createdAt: -1 })
      .lean();

    return res.status(200).json({
      successmessage: "Library identifications fetched",
      data: items,
    });
  } catch (err) {
    console.error("listMyLibrary error:", err.message);
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};

exports.deleteIdentification = async (req, res) => {
  try {
    const { id } = req.params;

    if (!req.user || !req.user._id) {
      return res
        .status(401)
        .json({ ok: false, error: "Unauthorized: user not found in token" });
    }

    const doc = await Identification.findOneAndDelete({
      _id: id,
      user: req.user._id,
    });

    if (!doc) {
      return res
        .status(404)
        .json({ ok: false, error: "Identification not found" });
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error("Error deleting identification:", err);
    return res.status(500).json({
      ok: false,
      error: "Error while deleting identification",
    });
  }
};
exports.saveToLibrary = async (req, res) => {
  try {
    const userId = req.user._id;
    const { id } = req.params;

    const updated = await Identification.findOneAndUpdate(
      { _id: id, user: userId },
      { savedToLibrary: true },
      { new: true },
    );

    if (!updated) {
      return res.status(404).json({ errormessage: "Identification not found" });
    }

    return res.status(200).json({
      successmessage: "Identification saved to library",
      data: updated,
    });
  } catch (err) {
    console.error("saveToLibrary error:", err.message);
    return res.status(500).json({ errormessage: "Erreur: " + err.message });
  }
};
