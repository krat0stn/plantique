// routes/authRoutes.js
const express = require("express");
const router = express.Router();
const multer = require("multer");
const rateLimit = require("express-rate-limit");

const { storage } = require("../config/cloudinary");
const upload = multer({ storage });

const AuthController = require("../controllers/authController");

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { errormessage: "Too many requests, please try again later." },
});

const passwordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { errormessage: "Too many attempts, please try again in an hour." },
});

router.post("/signin", authLimiter,AuthController.signin);
router.post("/supplier-signin", authLimiter, AuthController.supplierSignin);
router.post("/signup", authLimiter, upload.single("picture"), AuthController.signup);
router.post("/google-login", authLimiter, AuthController.googleLogin);
router.post("/forgot-password", passwordLimiter, AuthController.forgotPassword);
router.post("/reset-password", passwordLimiter, AuthController.resetPassword);
router.post("/verify-code", passwordLimiter, AuthController.verifyResetCode);

module.exports = router;
