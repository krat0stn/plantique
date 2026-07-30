const Product  = require("../models/Product");
const cloudinary = require("cloudinary").v2;

const SUPPLIER_FIELDS = "firstName lastName shopName logoUrl location";

const uploadToCloudinary = (buffer) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: "store/products", resource_type: "image" },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });

// ── Public ─────────────────────────────────────────────────────────────────────

// GET /api/store  — ?category=&supplierId=&q=&page=&limit=
exports.list = async (req, res) => {
  try {
    const { category, supplierId, q, page = 1, limit = 50 } = req.query;

    const filter = { isActive: true };
    if (category && category !== "All") filter.category = category;
    if (supplierId) filter.supplier = supplierId;
    if (q) filter.$text = { $search: q };

    const skip = (Number(page) - 1) * Number(limit);
    const [products, total] = await Promise.all([
      Product.find(filter)
        .populate("supplier", SUPPLIER_FIELDS)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Product.countDocuments(filter),
    ]);

    res.json({ data: products, total, page: Number(page) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/store/:id
exports.getById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id).populate(
      "supplier",
      SUPPLIER_FIELDS
    );
    if (!product) return res.status(404).json({ error: "Product not found" });
    res.json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/store/categories
exports.categories = async (req, res) => {
  try {
    const { supplierId } = req.query;
    const match = { isActive: true };
    if (supplierId) match.supplier = supplierId;
    const cats = await Product.distinct("category", match);
    res.json(["All", ...cats.sort()]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── Admin ──────────────────────────────────────────────────────────────────────

// POST /api/store
exports.create = async (req, res) => {
  try {
    const { name, supplier, price, category, description, inStock } = req.body;

    let imageUrl, imagePublicId;
    if (req.file) {
      const result = await uploadToCloudinary(req.file.buffer);
      imageUrl      = result.secure_url;
      imagePublicId = result.public_id;
    }

    const product = await Product.create({
      name,
      supplier, // ObjectId of Supplier
      price: Number(price),
      category,
      description,
      inStock: inStock !== "false",
      imageUrl,
      imagePublicId,
    });

    await product.populate("supplier", SUPPLIER_FIELDS);
    res.status(201).json(product);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/store/:id
exports.update = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ error: "Product not found" });

    const { name, supplier, price, category, description, inStock, isActive } =
      req.body;

    if (name        !== undefined) product.name        = name;
    if (supplier    !== undefined) product.supplier    = supplier;
    if (price       !== undefined) product.price       = Number(price);
    if (category    !== undefined) product.category    = category;
    if (description !== undefined) product.description = description;
    if (inStock     !== undefined) product.inStock     = inStock !== "false";
    if (isActive    !== undefined) product.isActive    = isActive !== "false";

    if (req.file) {
      if (product.imagePublicId) {
        await cloudinary.uploader.destroy(product.imagePublicId).catch(() => {});
      }
      const result      = await uploadToCloudinary(req.file.buffer);
      product.imageUrl      = result.secure_url;
      product.imagePublicId = result.public_id;
    }

    await product.save();
    await product.populate("supplier", SUPPLIER_FIELDS);
    res.json(product);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// DELETE /api/store/:id
exports.remove = async (req, res) => {
  try {
    const product = await Product.findByIdAndDelete(req.params.id);
    if (!product) return res.status(404).json({ error: "Product not found" });

    if (product.imagePublicId) {
      await cloudinary.uploader.destroy(product.imagePublicId).catch(() => {});
    }
    res.json({ message: "Product deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
