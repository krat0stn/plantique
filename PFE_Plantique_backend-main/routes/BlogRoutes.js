const express = require("express");
const router = express.Router();
const blogController = require("../controllers/blogController");

router.get("/", blogController.listPublic);
router.get("/:id", blogController.getPublicById);

module.exports = router;