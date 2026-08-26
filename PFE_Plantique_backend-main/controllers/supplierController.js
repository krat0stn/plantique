const Supplier = require("../models/Supplier");
const Product  = require("../models/Product");
const cloudinary = require("cloudinary").v2;
const bcrypt = require("bcrypt");

// Strips the password hash before a Supplier doc is sent to the client
const toSafeSupplier = (supplier) => {
  const obj = supplier.toObject ? supplier.toObject() : { ...supplier };
  delete obj.password;
  return obj;
};

const uploadLogo = (buffer) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: "store/suppliers", resource_type: "image" },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });

// ── Public reads ───────────────────────────────────────────────────────────────

// GET /api/suppliers
exports.list = async (_req, res) => {
  try {
    const suppliers = await Supplier.find({ isActive: true }).sort({ shopName: 1 });
    res.json(suppliers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/suppliers/:id
exports.getById = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });
    res.json(supplier);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/suppliers/with-stats
exports.withStats = async (_req, res) => {
  try {
    const suppliers = await Supplier.aggregate([
      { $match: { isActive: true } },
      {
        $lookup: {
          from: "products",
          let: { sid: "$_id" },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ["$supplier", "$$sid"] },
                    { $eq: ["$isActive", true] },
                  ],
                },
              },
            },
          ],
          as: "products",
        },
      },
      {
        $addFields: {
          productCount: { $size: "$products" },
          inStockCount: {
            $size: {
              $filter: {
                input: "$products",
                as: "p",
                cond: { $eq: ["$$p.inStock", true] },
              },
            },
          },
          categories: {
            $setUnion: [
              { $map: { input: "$products", as: "p", "in": "$$p.category" } },
              [],
            ],
          },
        },
      },
      {
        $project: {
          products:      0,
          logoPublicId:  0,
          updatedAt:     0,
          password:      0,
        },
      },
      { $sort: { shopName: 1 } },
    ]);
    res.json(suppliers);
  } catch (err) {
    console.error("withStats error:", err);
    res.status(500).json({ error: err.message });
  }
};

// GET /api/suppliers/admin  (admin only — includes inactive/suspended, with product counts)
exports.adminList = async (req, res) => {
  try {
    const { q } = req.query;
    const match = {};
    if (q) {
      match.$or = [
        { shopName:  { $regex: q, $options: "i" } },
        { firstName: { $regex: q, $options: "i" } },
        { lastName:  { $regex: q, $options: "i" } },
        { email:     { $regex: q, $options: "i" } },
      ];
    }

    const suppliers = await Supplier.aggregate([
      { $match: match },
      {
        $lookup: {
          from: "products",
          let: { sid: "$_id" },
          pipeline: [
            { $match: { $expr: { $eq: ["$supplier", "$$sid"] } } },
          ],
          as: "products",
        },
      },
      {
        $addFields: {
          productCount: { $size: "$products" },
        },
      },
      { $project: { products: 0, password: 0 } },
      { $sort: { shopName: 1 } },
    ]);

    res.json(suppliers);
  } catch (err) {
    console.error("adminList error:", err);
    res.status(500).json({ error: err.message });
  }
};

// ── Admin writes ───────────────────────────────────────────────────────────────

// POST /api/suppliers
exports.create = async (req, res) => {
  try {
    const { firstName, lastName, shopName, shopType, email, password, phone, location, bio, subscriptionStart, subscriptionEnd } = req.body;

    let logoUrl, logoPublicId;
    if (req.file) {
      const result = await uploadLogo(req.file.buffer);
      logoUrl      = result.secure_url;
      logoPublicId = result.public_id;
    }

    let hashedPassword;
    if (password) {
      const salt = await bcrypt.genSalt(10);
      hashedPassword = await bcrypt.hash(password, salt);
    }

    const supplier = await Supplier.create({
      firstName,
      lastName,
      shopName,
      shopType: shopType || undefined,
      email:    email    || undefined,
      password: hashedPassword,
      phone:    phone    || undefined,
      location: location || undefined,
      bio:      bio      || undefined,
      logoUrl,
      logoPublicId,
      subscriptionStart: subscriptionStart ? new Date(subscriptionStart) : undefined,
      subscriptionEnd:   subscriptionEnd   ? new Date(subscriptionEnd)   : undefined,
    });

    res.status(201).json(toSafeSupplier(supplier));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/suppliers/:id
exports.update = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });

    const { firstName, lastName, shopName, shopType, email, password, phone, location, bio, isActive, subscriptionStart, subscriptionEnd } = req.body;

    if (firstName !== undefined) supplier.firstName = firstName;
    if (lastName  !== undefined) supplier.lastName  = lastName;
    if (shopName  !== undefined) supplier.shopName  = shopName;
    if (shopType  !== undefined) supplier.shopType  = shopType || undefined;
    if (email     !== undefined) supplier.email     = email    || undefined;
    if (phone     !== undefined) supplier.phone     = phone    || undefined;
    if (location  !== undefined) supplier.location  = location || undefined;
    if (bio       !== undefined) supplier.bio       = bio      || undefined;
    if (isActive  !== undefined) supplier.isActive  = isActive !== "false";
    if (subscriptionStart !== undefined) supplier.subscriptionStart = subscriptionStart ? new Date(subscriptionStart) : null;
    if (subscriptionEnd   !== undefined) supplier.subscriptionEnd   = subscriptionEnd   ? new Date(subscriptionEnd)   : null;

    // Only touch the password if a new one was actually submitted
    if (password) {
      const salt = await bcrypt.genSalt(10);
      supplier.password = await bcrypt.hash(password, salt);
    }

    if (req.file) {
      if (supplier.logoPublicId) {
        await cloudinary.uploader.destroy(supplier.logoPublicId).catch(() => {});
      }
      const result         = await uploadLogo(req.file.buffer);
      supplier.logoUrl      = result.secure_url;
      supplier.logoPublicId = result.public_id;
    }

    await supplier.save();
    res.json(toSafeSupplier(supplier));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// DELETE /api/suppliers/:id
exports.remove = async (req, res) => {
  try {
    const supplier = await Supplier.findByIdAndDelete(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });

    if (supplier.logoPublicId) {
      await cloudinary.uploader.destroy(supplier.logoPublicId).catch(() => {});
    }

    await Product.updateMany(
      { supplier: supplier._id },
      { $set: { isActive: false } }
    );

    res.json({ message: "Supplier deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};