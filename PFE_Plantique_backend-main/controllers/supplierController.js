const Supplier = require("../models/Supplier");
const Product  = require("../models/Product");
const cloudinary = require("cloudinary").v2;

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

// ── Admin writes ───────────────────────────────────────────────────────────────

// POST /api/suppliers
exports.create = async (req, res) => {
  try {
    const { firstName, lastName, shopName, email, phone, location, bio } = req.body;

    let logoUrl, logoPublicId;
    if (req.file) {
      const result = await uploadLogo(req.file.buffer);
      logoUrl      = result.secure_url;
      logoPublicId = result.public_id;
    }

    const supplier = await Supplier.create({
      firstName,
      lastName,
      shopName,
      email:    email    || undefined,
      phone:    phone    || undefined,
      location: location || undefined,
      bio:      bio      || undefined,
      logoUrl,
      logoPublicId,
    });

    res.status(201).json(supplier);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/suppliers/:id
exports.update = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });

    const { firstName, lastName, shopName, email, phone, location, bio, isActive } = req.body;

    if (firstName !== undefined) supplier.firstName = firstName;
    if (lastName  !== undefined) supplier.lastName  = lastName;
    if (shopName  !== undefined) supplier.shopName  = shopName;
    if (email     !== undefined) supplier.email     = email    || undefined;
    if (phone     !== undefined) supplier.phone     = phone    || undefined;
    if (location  !== undefined) supplier.location  = location || undefined;
    if (bio       !== undefined) supplier.bio       = bio      || undefined;
    if (isActive  !== undefined) supplier.isActive  = isActive !== "false";

    if (req.file) {
      if (supplier.logoPublicId) {
        await cloudinary.uploader.destroy(supplier.logoPublicId).catch(() => {});
      }
      const result         = await uploadLogo(req.file.buffer);
      supplier.logoUrl      = result.secure_url;
      supplier.logoPublicId = result.public_id;
    }

    await supplier.save();
    res.json(supplier);
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
