const User = require("../models/User");
const Supplier = require("../models/Supplier");
const bcrypt = require("bcrypt");
const { Resend } = require("resend");
const { generateResetEmailTemplate } = require("../utils/emailTemplates");
const jwt = require("jsonwebtoken");
const validator = require("validator");
const { OAuth2Client } = require("google-auth-library");

const resend = new Resend(process.env.RESEND_API_KEY); 
// -----------------------
// Helpers
// -----------------------
function isAccountDisabled(user) {
  // Adjust if your schema uses other values (e.g. "Inactive", "Blocked")
  return user?.status && user.status !== "Active";
}

function signJwt(user) {
  return jwt.sign(
    { id: user._id, role: user.role, username: user.username },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );
}

// -----------------------
// SIGN IN (ENGLISH ERRORS)
// -----------------------
exports.signin = async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (!email || !password) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        errormessage: "Email and password are required.",
        errors: {
          email: !email ? "Email is required." : undefined,
          password: !password ? "Password is required." : undefined,
        },
      });
    }

    if (!validator.isEmail(email)) {
      return res.status(400).json({
        code: "INVALID_EMAIL_FORMAT",
        errormessage: "Invalid email address.",
        errors: { email: "Invalid email format." },
      });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({
        code: "EMAIL_NOT_FOUND",
        errormessage: "This email does not exist.",
        errors: { email: "This email does not exist." },
      });
    }

    if (isAccountDisabled(user)) {
      return res.status(403).json({
        code: "ACCOUNT_DISABLED",
        errormessage: "Account is disabled.",
      });
    }

    // If user.password is empty (e.g. created via Google), block password login
    if (!user.password) {
      return res.status(401).json({
        code: "PASSWORD_LOGIN_NOT_AVAILABLE",
        errormessage: "Password login is not available for this account.",
      });
    }

    const ok = await bcrypt.compare(password, user.password || "");
    if (!ok) {
      return res.status(401).json({
        code: "INVALID_PASSWORD",
        errormessage: "Incorrect password.",
        errors: { password: "Incorrect password." },
      });
    }

    const token = signJwt(user);
    const { password: _p, resetCode: _r, resetCodeExpires: _e, ...safeUser } = user.toObject();

    return res.status(200).json({
      message: "Signed in successfully.",
      token,
      user: safeUser,
    });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Server error: " + err.message,
    });
  }
};

// -----------------------
// SIGN UP (ENGLISH ERRORS)
// -----------------------
exports.signup = async (req, res) => {
  try {
    // Cloudinary (multer-storage-cloudinary) usually gives you a URL in file.path
    const pictureFromFile =
      req.file && (req.file.path || req.file.secure_url || req.file.filename)
        ? (req.file.path || req.file.secure_url || req.file.filename).toString()
        : null;

    const pictureFromBody =
      typeof req.body.picture === "string" && req.body.picture.trim()
        ? req.body.picture.trim()
        : null;

    const picture = pictureFromFile ?? pictureFromBody;

    const { username, email, password } = req.body || {};

    if (!username || !email || !password) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        errormessage: "All fields are required.",
      });
    }

    if (!validator.isEmail(email)) {
      return res.status(400).json({
        code: "INVALID_EMAIL_FORMAT",
        errormessage: "Invalid email address.",
      });
    }

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(400).json({
        code: "EMAIL_ALREADY_EXISTS",
        errormessage: "Email already exists.",
      });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = await User.create({
      username,
      email,
      password: hashedPassword,
      picture,
      role: "User",
      status: "Active",
    });

    const { password: _p, resetCode: _r, resetCodeExpires: _e, ...safeUser } = newUser.toObject();

    return res.status(201).json({
      successmessage: "User created successfully.",
      user: safeUser,
    });
  } catch (error) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Server error: " + error.message,
    });
  }
};

// -----------------------
// CREATE USER (admin create) - ENGLISH ERRORS
// -----------------------
exports.create = async (req, res) => {
  try {
    const { username, email, password, role, status, picture } = req.body || {};

    if (!username || !email || !password) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        errormessage: "All fields are required.",
      });
    }

    if (!validator.isEmail(email)) {
      return res.status(400).json({
        code: "INVALID_EMAIL_FORMAT",
        errormessage: "Invalid email address.",
      });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        code: "EMAIL_ALREADY_EXISTS",
        errormessage: "Email already exists.",
      });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const created = await User.create({
      username,
      email,
      password: hashedPassword,
      role: role || "User",
      status: status || "Active",
      picture:
        typeof picture === "string" && picture.trim() ? picture.trim() : null,
    });

    return res.status(201).json({
      successmessage: "User created successfully.",
      user: created,
    });
  } catch (error) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Error while creating user.",
      error: error.message,
    });
  }
};

// -----------------------
// FORGOT PASSWORD (ENGLISH ERRORS)
// -----------------------
exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body || {};

    if (!email) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        message: "Email is required.",
      });
    }

    if (!validator.isEmail(email)) {
      return res.status(400).json({
        code: "INVALID_EMAIL_FORMAT",
        message: "Invalid email address.",
      });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({
        code: "EMAIL_NOT_FOUND",
        message: "User not found.",
      });
    }

    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    user.resetCode = resetCode;
    user.resetCodeExpires = Date.now() + 15 * 60 * 1000;
    await user.save();

    if (!process.env.RESEND_API_KEY) {
      console.error("forgotPassword: RESEND_API_KEY is not set");
      return res.status(500).json({ code: "CONFIG_ERROR", message: "Email service not configured." });
    }

    const fromName = process.env.EMAIL_FROM_NAME || "Plantique";
    const fromAddress = process.env.EMAIL_FROM_ADDRESS || "onboarding@resend.dev";

    const { data, error: emailError } = await resend.emails.send({
      from: `${fromName} <${fromAddress}>`,
      to: user.email,
      subject: "Password reset",
      html: generateResetEmailTemplate(resetCode, user.username),
    });

    if (emailError) {
      console.error("Resend error:", emailError);
      return res.status(500).json({
        code: "EMAIL_SEND_ERROR",
        message: "Failed to send email.",
      });
    }

    console.log("Email sent, id:", data?.id);

    return res.status(200).json({
      message: "Reset code sent by email.",
    });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      message: "Server error: " + err.message,
    });
  }
};

// -----------------------
// VERIFY RESET CODE (ENGLISH ERRORS)
// -----------------------
exports.verifyResetCode = async (req, res) => {
  try {
    const { email, resetCode } = req.body || {};

    if (!email || !resetCode) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        message: "Email and reset code are required.",
      });
    }

    const user = await User.findOne({
      email,
      resetCode,
      resetCodeExpires: { $gt: Date.now() },
    });

    if (!user) {
      return res.status(400).json({
        code: "INVALID_OR_EXPIRED_CODE",
        message: "Invalid or expired code.",
      });
    }

    return res.status(200).json({ message: "Code verified." });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      message: "Server error: " + err.message,
    });
  }
};

// -----------------------
// RESET PASSWORD (ENGLISH ERRORS)
// -----------------------
exports.resetPassword = async (req, res) => {
  try {
    const { email, resetCode, newPassword, confirmPassword } = req.body || {};

    if (!email || !resetCode || !newPassword || !confirmPassword) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        message: "Missing required fields.",
      });
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        code: "PASSWORDS_NOT_MATCH",
        message: "Passwords do not match.",
      });
    }

    const user = await User.findOne({
      email,
      resetCode,
      resetCodeExpires: { $gt: Date.now() },
    });

    if (!user) {
      return res.status(400).json({
        code: "INVALID_OR_EXPIRED_CODE",
        message: "Invalid or expired code.",
      });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    user.resetCode = null;
    user.resetCodeExpires = null;
    await user.save();

    return res.status(200).json({
      message: "Password updated successfully.",
    });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      message: "Server error: " + err.message,
    });
  }
};

// -----------------------
// GOOGLE LOGIN (ENGLISH ERRORS)
// -----------------------
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

exports.googleLogin = async (req, res) => {
  const { tokenId } = req.body || {};
  if (!tokenId) {
    return res.status(400).json({
      code: "MISSING_FIELDS",
      message: "tokenId is required.",
    });
  }

  try {
    const ticket = await client.verifyIdToken({
      idToken: tokenId,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    const email = payload?.email;
    const name = payload?.name || "User";

    if (!email) {
      return res.status(400).json({
        code: "GOOGLE_PAYLOAD_INVALID",
        message: "Google email is missing.",
      });
    }

    let user = await User.findOne({ email });

    if (!user) {
      user = await User.create({
        username: name,
        email: email,
        role: "User",
        status: "Active",
      });
    }

    if (isAccountDisabled(user)) {
      return res.status(403).json({
        code: "ACCOUNT_DISABLED",
        message: "Account is disabled.",
      });
    }

    const token = signJwt(user);
    const { password: _p, resetCode: _r, resetCodeExpires: _e, ...safeUser } = user.toObject();

    return res.status(200).json({
      message: "Google sign-in successful.",
      token,
      user: safeUser,
    });
  } catch (error) {
    return res.status(400).json({
      code: "GOOGLE_LOGIN_FAILED",
      message: "Google sign-in failed.",
    });
  }
};

// -----------------------
// SUPPLIER SIGN IN
// -----------------------
exports.supplierSignin = async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (!email || !password) {
      return res.status(400).json({
        code: "MISSING_FIELDS",
        errormessage: "Email and password are required.",
      });
    }

    if (!validator.isEmail(email)) {
      return res.status(400).json({
        code: "INVALID_EMAIL_FORMAT",
        errormessage: "Invalid email address.",
      });
    }

    // Must select password explicitly (select: false on schema)
    const supplier = await Supplier.findOne({ email }).select("+password");
    if (!supplier) {
      return res.status(404).json({
        code: "EMAIL_NOT_FOUND",
        errormessage: "No supplier account found with this email.",
      });
    }

    if (!supplier.isActive) {
      return res.status(403).json({
        code: "ACCOUNT_DISABLED",
        errormessage: "This supplier account has been suspended.",
      });
    }

    if (!supplier.password) {
      return res.status(401).json({
        code: "PASSWORD_NOT_SET",
        errormessage: "No password is set for this account.",
      });
    }

    const ok = await bcrypt.compare(password, supplier.password);
    if (!ok) {
      return res.status(401).json({
        code: "INVALID_PASSWORD",
        errormessage: "Incorrect password.",
      });
    }

    const token = jwt.sign(
      {
        id: supplier._id,
        supplierId: supplier._id,
        role: "Supplier",
        shopName: supplier.shopName,
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    const safeSupplier = supplier.toObject();
    delete safeSupplier.password;

    return res.status(200).json({
      message: "Supplier signed in successfully.",
      token,
      user: { ...safeSupplier, role: "Supplier" },
    });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Server error: " + err.message,
    });
  }
};
