// middlewares/authMiddleware.js
const jwt = require("jsonwebtoken");
const Account = require("../models/Account");

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

  try {
    const account = await Account.findById(req.user.id).select("isActive subscriptionEnd role");
    if (!account) {
      return res.status(403).json({ errormessage: "Supplier account not found" });
    }
    if (account.role !== "Supplier") {
      return res.status(403).json({ errormessage: "Account is not a supplier" });
    }
    if (!account.isActive) {
      return res.status(403).json({ errormessage: "Supplier account is suspended" });
    }
    if (account.subscriptionEnd && new Date() > account.subscriptionEnd) {
      account.isActive = false;
      await account.save();
      return res.status(403).json({ errormessage: "Subscription expired. Account has been suspended." });
    }
  } catch (err) {
    // If DB check fails, let the request through
  }

  next();
};

exports.isUser = exports.allowRoles("User");
