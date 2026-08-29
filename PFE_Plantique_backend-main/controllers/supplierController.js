const Account = require("../models/Account");
const Product  = require("../models/Product");
const cloudinary = require("cloudinary").v2;
const bcrypt = require("bcrypt");

const toSafeAccount = (account) => {
  const obj = account.toObject ? account.toObject() : { ...account };
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

exports.list = async (_req, res) => {
  try {
    const suppliers = await Account.find({ role: "Supplier", isActive: true }).sort({ shopName: 1 });
    res.json(suppliers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getById = async (req, res) => {
  try {
    const supplier = await Account.findById(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });
    res.json(supplier);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.withStats = async (_req, res) => {
  try {
    const suppliers = await Account.aggregate([
      { $match: { role: "Supplier", isActive: true } },
      {
        $lookup: {
          from: "products",
          let: { sid: "$_id" },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ["$sellerId", "$$sid"] },
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

exports.adminList = async (req, res) => {
  try {
    const { q } = req.query;
    const match = { role: "Supplier" };
    if (q) {
      match.$or = [
        { shopName:  { $regex: q, $options: "i" } },
        { firstName: { $regex: q, $options: "i" } },
        { lastName:  { $regex: q, $options: "i" } },
        { email:     { $regex: q, $options: "i" } },
      ];
    }

    const suppliers = await Account.aggregate([
      { $match: match },
      {
        $lookup: {
          from: "products",
          let: { sid: "$_id" },
          pipeline: [
            { $match: { $expr: { $eq: ["$sellerId", "$$sid"] } } },
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

    const username = `${firstName || ""} ${lastName || ""}`.trim() || shopName || "Supplier";

    const supplier = await Account.create({
      username,
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
      role: "Supplier",
      status: "Active",
      isActive: true,
      subscriptionStart: subscriptionStart ? new Date(subscriptionStart) : undefined,
      subscriptionEnd:   subscriptionEnd   ? new Date(subscriptionEnd)   : undefined,
    });

    res.status(201).json(toSafeAccount(supplier));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

exports.update = async (req, res) => {
  try {
    const supplier = await Account.findById(req.params.id);
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

    // Update username when name changes
    if (firstName !== undefined || lastName !== undefined) {
      supplier.username = `${supplier.firstName || ""} ${supplier.lastName || ""}`.trim() || supplier.shopName || "Supplier";
    }

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
    res.json(toSafeAccount(supplier));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

exports.remove = async (req, res) => {
  try {
    const supplier = await Account.findByIdAndDelete(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });

    if (supplier.logoPublicId) {
      await cloudinary.uploader.destroy(supplier.logoPublicId).catch(() => {});
    }

    await Product.updateMany(
      { sellerId: supplier._id },
      { $set: { isActive: false } }
    );

    res.json({ message: "Supplier deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
