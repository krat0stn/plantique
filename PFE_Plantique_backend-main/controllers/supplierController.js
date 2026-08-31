const Account = require("../models/Account");
const Supplier = require("../models/Supplier");
const Product = require("../models/Product");
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

// Helper: Get full supplier data (account + supplier details)
const getFullSupplier = async (accountId) => {
  const account = await Account.findById(accountId);
  if (!account) return null;
  const supplier = await Supplier.findOne({ accountId });
  return { ...account.toObject(), supplier: supplier?.toObject() || null };
};

// Helper: Get full supplier by account ID (for aggregation lookups)
const supplierLookupPipeline = [
  {
    $lookup: {
      from: "suppliers",
      localField: "_id",
      foreignField: "accountId",
      as: "supplierDetails",
    },
  },
  {
    $unwind: {
      path: "$supplierDetails",
      preserveNullAndEmptyArrays: true,
    },
  },
  {
    $addFields: {
      firstName: "$supplierDetails.firstName",
      lastName: "$supplierDetails.lastName",
      shopName: "$supplierDetails.shopName",
      shopType: "$supplierDetails.shopType",
      phone: "$supplierDetails.phone",
      location: "$supplierDetails.location",
      bio: "$supplierDetails.bio",
      logoUrl: "$supplierDetails.logoUrl",
      logoPublicId: "$supplierDetails.logoPublicId",
      isActive: "$supplierDetails.isActive",
      subscriptionStart: "$supplierDetails.subscriptionStart",
      subscriptionEnd: "$supplierDetails.subscriptionEnd",
    },
  },
  {
    $project: {
      supplierDetails: 0,
    },
  },
];

// ── Public reads ───────────────────────────────────────────────────────────────

exports.list = async (_req, res) => {
  try {
    const suppliers = await Account.aggregate([
      ...supplierLookupPipeline,
      { $match: { role: "Supplier", isActive: true } },
      { $sort: { shopName: 1 } },
    ]);
    res.json(suppliers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getById = async (req, res) => {
  try {
    const supplier = await getFullSupplier(req.params.id);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });
    res.json(supplier);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.withStats = async (_req, res) => {
  try {
    const suppliers = await Account.aggregate([
      ...supplierLookupPipeline,
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
              { $map: { input: "$products", as: "p", in: "$$p.category" } },
              [],
            ],
          },
        },
      },
      {
        $project: {
          products: 0,
          logoPublicId: 0,
          updatedAt: 0,
          password: 0,
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
        { shopName: { $regex: q, $options: "i" } },
        { firstName: { $regex: q, $options: "i" } },
        { lastName: { $regex: q, $options: "i" } },
        { email: { $regex: q, $options: "i" } },
      ];
    }

    const suppliers = await Account.aggregate([
      ...supplierLookupPipeline,
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
      logoUrl = result.secure_url;
      logoPublicId = result.public_id;
    }

    let hashedPassword;
    if (password) {
      const salt = await bcrypt.genSalt(10);
      hashedPassword = await bcrypt.hash(password, salt);
    }

    const username = `${firstName || ""} ${lastName || ""}`.trim() || shopName || "Supplier";

    // Create account
    const account = await Account.create({
      username,
      email: email || undefined,
      password: hashedPassword,
      role: "Supplier",
      status: "Active",
    });

    // Create supplier details
    const supplier = await Supplier.create({
      accountId: account._id,
      firstName: firstName || undefined,
      lastName: lastName || undefined,
      shopName: shopName || undefined,
      shopType: shopType || undefined,
      phone: phone || undefined,
      location: location || undefined,
      bio: bio || undefined,
      logoUrl,
      logoPublicId,
      isActive: true,
      subscriptionStart: subscriptionStart ? new Date(subscriptionStart) : undefined,
      subscriptionEnd: subscriptionEnd ? new Date(subscriptionEnd) : undefined,
    });

    const fullSupplier = await getFullSupplier(account._id);
    res.status(201).json(toSafeAccount(fullSupplier));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

exports.update = async (req, res) => {
  try {
    const account = await Account.findById(req.params.id);
    if (!account) return res.status(404).json({ error: "Supplier not found" });

    let supplier = await Supplier.findOne({ accountId: account._id });
    if (!supplier) {
      // Create supplier record if missing
      supplier = await Supplier.create({ accountId: account._id });
    }

    const { firstName, lastName, shopName, shopType, email, password, phone, location, bio, isActive, subscriptionStart, subscriptionEnd } = req.body;

    // Update supplier fields
    if (firstName !== undefined) supplier.firstName = firstName;
    if (lastName !== undefined) supplier.lastName = lastName;
    if (shopName !== undefined) supplier.shopName = shopName;
    if (shopType !== undefined) supplier.shopType = shopType || undefined;
    if (phone !== undefined) supplier.phone = phone || undefined;
    if (location !== undefined) supplier.location = location || undefined;
    if (bio !== undefined) supplier.bio = bio || undefined;
    if (isActive !== undefined) supplier.isActive = isActive !== "false";
    if (subscriptionStart !== undefined) supplier.subscriptionStart = subscriptionStart ? new Date(subscriptionStart) : null;
    if (subscriptionEnd !== undefined) supplier.subscriptionEnd = subscriptionEnd ? new Date(subscriptionEnd) : null;

    // Update account fields
    if (email !== undefined) account.email = email || undefined;

    // Update username when name changes
    if (firstName !== undefined || lastName !== undefined) {
      account.username = `${supplier.firstName || ""} ${supplier.lastName || ""}`.trim() || supplier.shopName || "Supplier";
    }

    if (password) {
      const salt = await bcrypt.genSalt(10);
      account.password = await bcrypt.hash(password, salt);
    }

    if (req.file) {
      if (supplier.logoPublicId) {
        await cloudinary.uploader.destroy(supplier.logoPublicId).catch(() => {});
      }
      const result = await uploadLogo(req.file.buffer);
      supplier.logoUrl = result.secure_url;
      supplier.logoPublicId = result.public_id;
    }

    await supplier.save();
    await account.save();

    const fullSupplier = await getFullSupplier(account._id);
    res.json(toSafeAccount(fullSupplier));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

exports.remove = async (req, res) => {
  try {
    const account = await Account.findByIdAndDelete(req.params.id);
    if (!account) return res.status(404).json({ error: "Supplier not found" });

    const supplier = await Supplier.findOneAndDelete({ accountId: account._id });

    if (supplier?.logoPublicId) {
      await cloudinary.uploader.destroy(supplier.logoPublicId).catch(() => {});
    }

    await Product.updateMany(
      { sellerId: account._id },
      { $set: { isActive: false } }
    );

    res.json({ message: "Supplier deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
