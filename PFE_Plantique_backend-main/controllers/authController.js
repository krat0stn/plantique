const Account = require("../models/Account");
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
function isAccountDisabled(account) {
  return account?.status && account.status !== "Active";
}

function signJwt(account, supplierData) {
  const payload = {
    id: account._id,
    role: account.role,
    username: account.username,
  };
  if (account.role === "Supplier" && supplierData) {
    payload.supplierId = account._id;
    payload.shopName = supplierData.shopName;
  }
  return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: "7d" });
}

// -----------------------
// SIGN IN
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

    const account = await Account.findOne({ email }).select("+password");

    if (!account) {
      return res.status(404).json({
        code: "EMAIL_NOT_FOUND",
        errormessage: "This email does not exist.",
        errors: { email: "This email does not exist." },
      });
    }

    if (isAccountDisabled(account)) {
      return res.status(403).json({
        code: "ACCOUNT_DISABLED",
        errormessage: "Account is disabled.",
      });
    }

    if (account.role === "Supplier") {
      const supplier = await Supplier.findOne({ accountId: account._id });
      if (supplier && !supplier.isActive) {
        return res.status(403).json({
          code: "ACCOUNT_DISABLED",
          errormessage: "This supplier account has been suspended.",
        });
      }
    }

    if (!account.password) {
      return res.status(401).json({
        code: "PASSWORD_LOGIN_NOT_AVAILABLE",
        errormessage: "Password login is not available for this account.",
      });
    }

    const ok = await bcrypt.compare(password, account.password || "");
    if (!ok) {
      return res.status(401).json({
        code: "INVALID_PASSWORD",
        errormessage: "Incorrect password.",
        errors: { password: "Incorrect password." },
      });
    }

    const { password: _p, resetCode: _r, resetCodeExpires: _e, ...safeAccount } = account.toObject();

    // For suppliers, merge supplier data
    let userData = safeAccount;
    let supplierData = null;
    if (account.role === "Supplier") {
      supplierData = await Supplier.findOne({ accountId: account._id });
      if (supplierData) {
        userData = { ...safeAccount, ...supplierData.toObject() };
      }
    }

    const token = signJwt(account, supplierData);

    return res.status(200).json({
      message: "Signed in successfully.",
      token,
      user: userData,
    });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Server error: " + err.message,
    });
  }
};

// -----------------------
// SIGN UP
// -----------------------
exports.signup = async (req, res) => {
  try {
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

    const existing = await Account.findOne({ email });
    if (existing) {
      return res.status(400).json({
        code: "EMAIL_ALREADY_EXISTS",
        errormessage: "Email already exists.",
      });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newAccount = await Account.create({
      username,
      email,
      password: hashedPassword,
      picture,
      role: "User",
      status: "Active",
    });

    const { password: _p, resetCode: _r, resetCodeExpires: _e, ...safeAccount } = newAccount.toObject();

    return res.status(201).json({
      successmessage: "User created successfully.",
      user: safeAccount,
    });
  } catch (error) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Server error: " + error.message,
    });
  }
};

// -----------------------
// CREATE USER (admin create)
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

    const existing = await Account.findOne({ email });
    if (existing) {
      return res.status(400).json({
        code: "EMAIL_ALREADY_EXISTS",
        errormessage: "Email already exists.",
      });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const created = await Account.create({
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
// FORGOT PASSWORD
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

    const account = await Account.findOne({ email });
    if (!account) {
      return res.status(404).json({
        code: "EMAIL_NOT_FOUND",
        message: "User not found.",
      });
    }

    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    account.resetCode = resetCode;
    account.resetCodeExpires = Date.now() + 15 * 60 * 1000;
    await account.save();

    if (!process.env.RESEND_API_KEY) {
      console.error("forgotPassword: RESEND_API_KEY is not set");
      return res.status(500).json({ code: "CONFIG_ERROR", message: "Email service not configured." });
    }

    const fromName = process.env.EMAIL_FROM_NAME || "Plantique";
    const fromAddress = process.env.EMAIL_FROM_ADDRESS || "onboarding@resend.dev";

    const { data, error: emailError } = await resend.emails.send({
      from: `${fromName} <${fromAddress}>`,
      to: account.email,
      subject: "Password reset",
      html: generateResetEmailTemplate(resetCode, account.username),
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
// VERIFY RESET CODE
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

    const account = await Account.findOne({
      email,
      resetCode,
      resetCodeExpires: { $gt: Date.now() },
    });

    if (!account) {
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
// RESET PASSWORD
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

    const account = await Account.findOne({
      email,
      resetCode,
      resetCodeExpires: { $gt: Date.now() },
    }).select("+password");

    if (!account) {
      return res.status(400).json({
        code: "INVALID_OR_EXPIRED_CODE",
        message: "Invalid or expired code.",
      });
    }

    const salt = await bcrypt.genSalt(10);
    account.password = await bcrypt.hash(newPassword, salt);
    account.resetCode = null;
    account.resetCodeExpires = null;
    await account.save();

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
// GOOGLE LOGIN
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

    let account = await Account.findOne({ email });

    if (!account) {
      account = await Account.create({
        username: name,
        email: email,
        role: "User",
        status: "Active",
      });
    }

    if (isAccountDisabled(account)) {
      return res.status(403).json({
        code: "ACCOUNT_DISABLED",
        message: "Account is disabled.",
      });
    }

    const token = signJwt(account);
    const { password: _p, resetCode: _r, resetCodeExpires: _e, ...safeAccount } = account.toObject();

    return res.status(200).json({
      message: "Google sign-in successful.",
      token,
      user: safeAccount,
    });
  } catch (error) {
    return res.status(400).json({
      code: "GOOGLE_LOGIN_FAILED",
      message: "Google sign-in failed.",
    });
  }
};

// -----------------------
// SUPPLIER SIGN IN (backward-compat endpoint)
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

    const account = await Account.findOne({ email, role: "Supplier" }).select("+password");
    if (!account) {
      return res.status(404).json({
        code: "EMAIL_NOT_FOUND",
        errormessage: "No supplier account found with this email.",
      });
    }

    const supplier = await Supplier.findOne({ accountId: account._id });
    if (!supplier) {
      return res.status(404).json({
        code: "SUPPLIER_NOT_FOUND",
        errormessage: "Supplier details not found.",
      });
    }

    if (!supplier.isActive) {
      return res.status(403).json({
        code: "ACCOUNT_DISABLED",
        errormessage: "This supplier account has been suspended.",
      });
    }

    if (!account.password) {
      return res.status(401).json({
        code: "PASSWORD_NOT_SET",
        errormessage: "No password is set for this account.",
      });
    }

    const ok = await bcrypt.compare(password, account.password);
    if (!ok) {
      return res.status(401).json({
        code: "INVALID_PASSWORD",
        errormessage: "Incorrect password.",
      });
    }

    const { password: _p, ...safeAccount } = account.toObject();

    // Merge supplier data
    let userData = safeAccount;
    if (supplier) {
      userData = { ...safeAccount, ...supplier.toObject() };
    }

    const token = signJwt(account, supplier);

    return res.status(200).json({
      message: "Supplier signed in successfully.",
      token,
      user: userData,
    });
  } catch (err) {
    return res.status(500).json({
      code: "SERVER_ERROR",
      errormessage: "Server error: " + err.message,
    });
  }
};
