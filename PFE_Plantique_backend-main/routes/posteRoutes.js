const express = require("express");
const router = express.Router();
const ctrl = require("../controllers/posteController");

const multer = require("multer");
const { storage } = require("../config/cloudinary");
const upload = multer({ storage });

const posteController = require("../controllers/posteController");
const commentController = require("../controllers/commentController");
const likeController = require("../controllers/likeController");
const saveController = require("../controllers/saveController");
const { verifyToken, isAdmin } = require("../middlewares/authMiddleware");

function mustBeFn(fn, name) {
  if (typeof fn !== "function") {
    throw new TypeError(`${name} must be a function, got ${typeof fn}`);
  }
}

// sanity checks
mustBeFn(verifyToken, "verifyToken");
mustBeFn(isAdmin, "isAdmin");
[
  "create",
  "updateSinglePoste",
  "getAllPostesPublic",
  "getPosteById",
  "deleteSinglePoste",
  "approve",
  "decline",
  "setPending",
].forEach((n) => mustBeFn(posteController[n], `posteController.${n}`));
["create", "list", "remove"].forEach((n) =>
  mustBeFn(commentController[n], `commentController.${n}`)
);
["toggle", "listByPost", "myLikedPosts"].forEach((n) =>
  mustBeFn(likeController[n], `likeController.${n}`)
);
["toggle", "listByPost", "mySavedPosts"].forEach((n) =>
  mustBeFn(saveController[n], `saveController.${n}`)
);

// create/update
router.post("/", verifyToken, upload.single("picture"), posteController.create);
router.put(
  "/:id",
  verifyToken,
  upload.single("picture"),
  posteController.updateSinglePoste
);

// feed
router.get("/", posteController.getAllPostesPublic);
router.get("/admin/all", verifyToken, isAdmin, posteController.getAllPostesAdmin);

// likes & saves
router.get("/liked/me", verifyToken, likeController.myLikedPosts);
router.get("/saved/me", verifyToken, saveController.mySavedPosts);

router.put("/:id/like", verifyToken, likeController.toggle);
router.get("/:id/likes", likeController.listByPost);

router.put("/:id/save", verifyToken, saveController.toggle);
router.get("/:id/saves", saveController.listByPost);

// comments
router.post("/:id/comments", verifyToken, commentController.create);
router.get("/:id/comments", commentController.list);
router.delete(
  "/:id/comments/:commentId",
  verifyToken,
  commentController.remove
);

// by id / admin
router.get("/:id", posteController.getPosteById);
router.delete("/:id", verifyToken, posteController.deleteSinglePoste);
router.put("/:id/approve", verifyToken, isAdmin, posteController.approve);
router.put("/:id/decline", verifyToken, isAdmin, posteController.decline);
router.put("/:id/pending", verifyToken, isAdmin, posteController.setPending);
// routes/posteRoutes.js
router.get("/mine", verifyToken, ctrl.listMine);

// controllers/posteController.js
exports.listMine = async (req, res) => {
  const posts = await Poste.find({ userId: req.user.id }).sort({
    createdAt: -1,
  });
  return res.json({ data: posts });
};

// Efficient saved list:
router.get("/saved", verifyToken, ctrl.listMySavedPosts);

exports.listMySavedPosts = async (req, res) => {
  const ids = await Save.find({ userId: req.user.id }).distinct("posteId");
  const posts = await Poste.find({ _id: { $in: ids } }).sort({ createdAt: -1 });
  res.json({ data: posts });
};

module.exports = router;