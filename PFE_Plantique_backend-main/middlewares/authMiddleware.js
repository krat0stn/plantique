// middlewares/authMiddleware.js
const jwt = require("jsonwebtoken");
const Supplier = require("../models/Supplier");

function getToken(req) {
  const h = req.headers["authorization"] || "";
  if (typeof h === "string" && h.toLowerCase().startsWith("bearer "))
    return h.slice(7).trim();
  if (req.cookies?.access_token) return req.cookies.access_token;
  return null;
}

exports.verifyToken = (req, res, next) => {
  const token = getToken(req);
  if (!token) {
    return res
      .status(401)
      .json({ errormessage: "Token requis pour accéder à cette ressource" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.id || decoded._id || decoded.userId;
    const role = decoded.role;

    if (!userId || !role) {
      return res
        .status(401)
        .json({ errormessage: "Token invalide: claims manquants (id/role)" });
    }

    req.user = {
      _id: userId,
      id: userId,
      role,
      // Supplier-specific claim (set when role === 'Supplier')
      supplierId: decoded.supplierId || null,
    };
    res.locals.userId = userId;
    res.locals.userRole = role;

    next();
  } catch (err) {
    return res.status(401).json({ errormessage: "Token invalide ou expiré" });
  }
};


exports.allowRoles =
  (...roles) =>
  (req, res, next) => {
    const role = req.user?.role || res.locals.userRole;
    if (!role || !roles.includes(role)) {
      return res
        .status(403)
        .json({ errormessage: "Accès refusé. Rôle insuffisant." });
    }
    next();
  };

exports.isAdmin = (req, res, next) => {
  if (req.user.role?.toLowerCase() !== "admin") {
    return res.status(403).json({ errormessage: "Admin access required" });
  }
  next();
};

exports.isSupplier = async (req, res, next) => {
  if (req.user.role !== "Supplier") {
    return res.status(403).json({ errormessage: "Supplier access required" });
  }
  if (!req.user.supplierId) {
    return res.status(403).json({ errormessage: "Supplier identity missing from token" });
  }

  // Check if subscription has expired → auto-suspend
  try {
    const supplier = await Supplier.findById(req.user.supplierId).select("isActive subscriptionEnd");
    if (!supplier) {
      return res.status(403).json({ errormessage: "Supplier account not found" });
    }
    if (!supplier.isActive) {
      return res.status(403).json({ errormessage: "Supplier account is suspended" });
    }
    if (supplier.subscriptionEnd && new Date() > supplier.subscriptionEnd) {
      supplier.isActive = false;
      await supplier.save();
      return res.status(403).json({ errormessage: "Subscription expired. Account has been suspended." });
    }
  } catch (err) {
    // If DB check fails, let the request through (don't block on infra errors)
  }

  next();
};

exports.isUser = exports.allowRoles("User");
