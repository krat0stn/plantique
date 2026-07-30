const Save = require("../models/Save");
const Poste = require("../models/Poste");

// PUT /api/postes/:id/save
exports.toggle = async (req, res) => {
  try {
    const posteId = req.params.id;
    const userId = req.user?.id;

    const found = await Save.findOne({ posteId, userId });
    let saved;
    if (found) {
      await Save.deleteOne({ _id: found._id });
      await Poste.findByIdAndUpdate(posteId, { $inc: { savedCount: -1 } });
      saved = false;
    } else {
      await Save.create({ posteId, userId });
      await Poste.findByIdAndUpdate(posteId, { $inc: { savedCount: 1 } });
      saved = true;
    }

    const post = await Poste.findById(posteId).select("savedCount");
    return res.status(200).json({
      successmessage: "Save toggled",
      data: { saved, savedCount: post?.savedCount ?? 0 },
    });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// GET /api/postes/:id/saves
exports.listByPost = async (req, res) => {
  try {
    const items = await Save.find({ posteId: req.params.id }).populate(
      "userId",
      "username picture"
    );
    return res.status(200).json({ data: items });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};

// GET /api/postes/saved/me
exports.mySavedPosts = async (req, res) => {
  try {
    const items = await Save.find({ userId: req.user.id }).select("posteId");
    return res.status(200).json({ data: items.map((i) => i.posteId) });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur: " + e.message });
  }
};
