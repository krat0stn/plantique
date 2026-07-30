// controllers/userController.js
const User = require("../models/User");
const bcrypt = require("bcrypt");
const validator = require("validator");

// GET /api/users
exports.getAllUsers = async (req, res) => {
  try {
    const response = await User.find(
      { role: { $ne: "Admin" } },
      "username email picture status createdAt role",
    ).sort({ createdAt: -1 });

    return res.status(200).json({
      successmessage: "Les Utilisateurs ont été récupérés avec succès",
      data: response,
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur " + error.message });
  }
};

// GET /api/users/:id
exports.getSingleUser = async (req, res) => {
  const { id } = req.params;
  try {
    const response = await User.findById(id).select(
      "username email picture status createdAt role",
    );
    if (!response)
      return res.status(404).json({ errormessage: "utilisateur introuvable" });

    return res.status(200).json({
      successmessage: "utilisateur a été récupéré avec succès",
      data: response,
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur " + error.message });
  }
};

// POST /api/users (multipart: username, email, password, role?, picture?)
exports.create = async (req, res) => {
  try {
    const body = req.body || {};
    const { username, email, password } = body;
    const role =
      body.role && (body.role === "Admin" || body.role === "User")
        ? body.role
        : "User";

    if (!username || !email || !password) {
      return res
        .status(400)
        .json({ errormessage: "Tous les champs sont obligatoires" });
    }
    if (!validator.isEmail(email)) {
      return res.status(400).json({ errormessage: "Adresse e-mail invalide" });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ errormessage: "Email déjà existant" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const picture = req.file?.path || null;

    const newUser = await User.create({
      username,
      email,
      password: hashedPassword,
      role,
      ...(picture ? { picture } : {}),
    });

    return res
      .status(201)
      .json({ successmessage: "Utilisateur créé avec succès", user: newUser });
  } catch (error) {
    return res.status(500).json({
      errormessage: "Erreur lors de la création de l'utilisateur",
      error: error.message,
    });
  }
};

// GET /api/users/me
exports.getMe = async (req, res) => {
  try {
    const u = await User.findById(req.user.id).select(
      "username email picture role createdAt status",
    );
    if (!u)
      return res.status(404).json({ errormessage: "Utilisateur introuvable" });
    return res.json({ user: u });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur " + e.message });
  }
};

// PUT|PATCH /api/users/me (multipart: username?, email?, picture?)
exports.updateMe = async (req, res) => {
  try {
    const updates = {};
    const body = req.body || {};

    if (typeof body.username === "string") {
      updates.username = body.username.trim();
    }

    if (typeof body.email === "string") {
      const email = body.email.trim();
      if (!validator.isEmail(email)) {
        return res
          .status(400)
          .json({ errormessage: "Adresse e-mail invalide" });
      }
      // Prevent duplicate emails
      const exists = await User.findOne({ email, _id: { $ne: req.user.id } });
      if (exists) {
        return res.status(400).json({ errormessage: "Email déjà existant" });
      }
      updates.email = email;
    }

    if (req.file?.path) {
      updates.picture = req.file.path; // Cloudinary URL
    }

    const u = await User.findByIdAndUpdate(req.user.id, updates, {
      new: true,
    }).select("username email picture role createdAt status");

    if (!u)
      return res.status(404).json({ errormessage: "Utilisateur introuvable" });

    return res.json({ successmessage: "Profil mis à jour", user: u });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur " + e.message });
  }
};

// PUT /api/users/me/password  {currentPassword, newPassword}
exports.changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  try {
    const u = await User.findById(req.user.id).select("+password");
    if (!u)
      return res.status(404).json({ errormessage: "Utilisateur introuvable" });

    const ok = await bcrypt.compare(currentPassword || "", u.password || "");
    if (!ok)
      return res
        .status(400)
        .json({ errormessage: "Mot de passe actuel invalide" });

    const salt = await bcrypt.genSalt(10);
    u.password = await bcrypt.hash(newPassword, salt);
    await u.save();
    return res.json({ successmessage: "Mot de passe mis à jour" });
  } catch (e) {
    return res.status(500).json({ errormessage: "Erreur " + e.message });
  }
};

// PUT|PATCH /api/users/:id (Admin edit: ONLY role + optional picture)
exports.updateSingleUser = async (req, res) => {
  const { id } = req.params;
  
  try {
    const body = req.body || {};
    const updateData = {};

    // Handle username
    if (typeof body.username === "string") {
      updateData.username = body.username.trim();
    }

    // Handle email
    if (typeof body.email === "string") {
      const email = body.email.trim();
      if (!validator.isEmail(email)) {
        return res.status(400).json({ errormessage: "Adresse e-mail invalide" });
      }
      const exists = await User.findOne({ email, _id: { $ne: id } });
      if (exists) {
        return res.status(400).json({ errormessage: "Email déjà existant" });
      }
      updateData.email = email;
    }

    // Handle status
    if (typeof body.status === "string") {
      updateData.status = body.status;
    }

    // Handle role
    if (typeof body.role !== "undefined") {
      if (body.role !== "Admin" && body.role !== "User") {
        return res.status(400).json({ errormessage: "Rôle invalide" });
      }
      updateData.role = body.role;
    }

    // Handle picture
    if (req.file?.path) {
      updateData.picture = req.file.path;
    }

    const updated = await User.findByIdAndUpdate(id, updateData, {
      new: true,
    }).select("username email picture status createdAt role");

    if (!updated) {
      return res.status(404).json({ errormessage: "Utilisateur introuvable" });
    }

    return res.status(200).json({
      successmessage: "Utilisateur mis à jour avec succès",
      data: updated,
    });
  } catch (error) {
    return res
      .status(500)
      .json({ errormessage: "Erreur du serveur: " + error.message });
  }
};

// DELETE /api/users/:id
exports.deleteSingleUser = async (req, res) => {
  const { id } = req.params;
  try {
    const deleted = await User.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ errormessage: "Utilisateur introuvable" });
    }
    return res.status(200).json({
      successmessage: "utilisateur supprimé avec succès",
      data: deleted,
    });
  } catch (error) {
    return res.status(500).json({ errormessage: "Erreur: " + error.message });
  }
};
