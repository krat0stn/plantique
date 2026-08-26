// controllers/supplierDashboardController.js
/**
 * All handlers here require verifyToken + isSupplier middleware.
 * The authenticated supplier's ID is ALWAYS taken from req.user.supplierId (JWT claim).
 * Never trust supplier IDs from the request body/params for ownership checks.
 */
const Product  = require("../models/Product");
const Poste    = require("../models/Poste");
const Blog     = require("../models/Blog");
const Purchase = require("../models/Purchase");
const Supplier = require("../models/Supplier");
const User     = require("../models/User");
const PDFDocument = require("pdfkit");
const XLSX = require("xlsx");
const cloudinary = require("cloudinary").v2;

const {
  createNotification,
  createNotificationForMany,
} = require("./notificationController");

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

const uploadToCloudinary = (buffer, folder) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: "image" },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });

// Generate next receipt number for a supplier (RE01, RE02, ...)
const getNextReceiptNumber = async (supplierId) => {
  const count = await Purchase.countDocuments({ supplierId });
  const num = count + 1;
  return `RE${String(num).padStart(2, "0")}`;
};

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTS
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/supplier-dashboard/products
exports.listProducts = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const products = await Product.find({ supplier: supplierId, isActive: true })
      .sort({ createdAt: -1 });
    res.json({ data: products });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/supplier-dashboard/products
exports.createProduct = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const { name, category, price, quantity, description, inStock } = req.body;

    if (!name || !category || price === undefined) {
      return res.status(400).json({ error: "name, category and price are required" });
    }

    let imageUrl, imagePublicId;
    if (req.file) {
      const result = await uploadToCloudinary(req.file.buffer, "store/products");
      imageUrl      = result.secure_url;
      imagePublicId = result.public_id;
    }

    const product = await Product.create({
      name,
      supplier: supplierId,          // always from JWT
      price: Number(price),
      category,
      quantity: Number(quantity) || 0,
      description: description || "",
      inStock: inStock !== "false",
      imageUrl,
      imagePublicId,
    });

    res.status(201).json({ data: product });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/supplier-dashboard/products/:id
exports.updateProduct = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const product = await Product.findById(req.params.id);

    if (!product) return res.status(404).json({ error: "Product not found" });

    // Enforce ownership
    if (product.supplier.toString() !== supplierId.toString()) {
      return res.status(403).json({ error: "Not your product" });
    }

    const { name, category, price, quantity, description, inStock } = req.body;
    if (name     !== undefined) product.name     = name;
    if (category !== undefined) product.category = category;
    if (price    !== undefined) product.price    = Number(price);
    if (quantity !== undefined) product.quantity = Number(quantity);
    if (description !== undefined) product.description = description;
    if (inStock  !== undefined) product.inStock  = inStock !== "false";

    if (req.file) {
      if (product.imagePublicId) {
        await cloudinary.uploader.destroy(product.imagePublicId).catch(() => {});
      }
      const result = await uploadToCloudinary(req.file.buffer, "store/products");
      product.imageUrl      = result.secure_url;
      product.imagePublicId = result.public_id;
    }

    await product.save();
    res.json({ data: product });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// DELETE /api/supplier-dashboard/products/:id
exports.deleteProduct = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const product = await Product.findById(req.params.id);

    if (!product) return res.status(404).json({ error: "Product not found" });

    if (product.supplier.toString() !== supplierId.toString()) {
      return res.status(403).json({ error: "Not your product" });
    }

    if (product.imagePublicId) {
      await cloudinary.uploader.destroy(product.imagePublicId).catch(() => {});
    }
    await product.deleteOne();
    res.json({ message: "Product deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/supplier-dashboard/products/import
// Accepts a CSV or Excel file. Expected columns: name, category, price, quantity, description, inStock
exports.importProducts = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;

    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    const workbook = XLSX.read(req.file.buffer, { type: "buffer" });
    const sheetName = workbook.SheetNames[0];
    const rows = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName]);

    if (rows.length === 0) {
      return res.status(400).json({ error: "File is empty" });
    }

    const products = [];
    const errors = [];

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const name = (row.name || row.Name || "").toString().trim();
      const category = (row.category || row.Category || "").toString().trim();
      const price = parseFloat(row.price ?? row.Price);
      const quantity = parseInt(row.quantity ?? row.Quantity ?? "0", 10);
      const description = (row.description ?? row.Description ?? "").toString().trim();
      const inStockRaw = row.inStock ?? row.InStock ?? row.in_stock ?? "true";
      const inStock = inStockRaw === "false" || inStockRaw === "0" ? false : true;

      if (!name || !category || isNaN(price)) {
        errors.push(`Row ${i + 2}: missing name, category, or invalid price`);
        continue;
      }

      products.push({
        name,
        category,
        price,
        quantity: isNaN(quantity) ? 0 : quantity,
        description,
        inStock,
        supplier: supplierId,
      });
    }

    let created = [];
    if (products.length > 0) {
      created = await Product.insertMany(products);
    }

    res.status(201).json({
      data: {
        imported: created.length,
        errors: errors,
        totalRows: rows.length,
      },
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POSTS
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/supplier-dashboard/posts
exports.listPosts = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const posts = await Poste.find({ supplierId }).sort({ createdAt: -1 });
    res.json({ data: posts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/supplier-dashboard/posts
exports.createPost = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const { content } = req.body;

    if (!content || !content.trim()) {
      return res.status(400).json({ error: "content is required" });
    }

    let picturePath = null;
    if (req.file) picturePath = req.file.path || req.file.secure_url || null;

    const post = await Poste.create({
      supplierId,
      content: content.trim(),
      picture: picturePath,
      status: "pending",             // always pending for supplier content
    });

    // Notify all admins of new supplier post needing review
    try {
      const admins = await User.find({ role: "Admin" }).select("_id");
      const adminIds = admins.map((a) => a._id);
      if (adminIds.length > 0) {
        await createNotificationForMany({
          userIds: adminIds,
          type: "post",
          title: "New supplier post to review",
          message: "A supplier has created a new post that needs review.",
          postId: post._id,
        });
      }
    } catch (notifyErr) {
      console.error("Supplier post admin notification error:", notifyErr.message);
    }

    res.status(201).json({ data: post });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/supplier-dashboard/posts/:id
exports.updatePost = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const post = await Poste.findById(req.params.id);

    if (!post) return res.status(404).json({ error: "Post not found" });

    if (!post.supplierId || post.supplierId.toString() !== supplierId.toString()) {
      return res.status(403).json({ error: "Not your post" });
    }

    const { content } = req.body;
    if (content !== undefined) {
      if (!content.trim()) return res.status(400).json({ error: "content cannot be empty" });
      post.content = content.trim();
    }

    if (req.file) {
      post.picture = req.file.path || req.file.secure_url || null;
    }

    // Editing a post resets status to pending for admin re-review
    post.status = "pending";
    await post.save();

    // Notify admins of edited supplier post
    try {
      const admins = await User.find({ role: "Admin" }).select("_id");
      const adminIds = admins.map((a) => a._id);
      if (adminIds.length > 0) {
        await createNotificationForMany({
          userIds: adminIds,
          type: "post",
          title: "Supplier post updated – needs review",
          message: "A supplier edited a post; it has been reset to pending.",
          postId: post._id,
        });
      }
    } catch (notifyErr) {
      console.error("Supplier post update admin notification error:", notifyErr.message);
    }

    res.json({ data: post });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// DELETE /api/supplier-dashboard/posts/:id
exports.deletePost = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const post = await Poste.findById(req.params.id);

    if (!post) return res.status(404).json({ error: "Post not found" });

    if (!post.supplierId || post.supplierId.toString() !== supplierId.toString()) {
      return res.status(403).json({ error: "Not your post" });
    }

    await post.deleteOne();
    res.json({ message: "Post deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// BLOGS
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/supplier-dashboard/blogs
exports.listBlogs = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const blogs = await Blog.find({ supplierId }).sort({ createdAt: -1 });
    res.json({ data: blogs });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/supplier-dashboard/blogs
exports.createBlog = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const { title, content, excerpt } = req.body;

    if (!title || !content) {
      return res.status(400).json({ error: "title and content are required" });
    }

    let imageUrl, imagePublicId;
    if (req.file) {
      const result = await uploadToCloudinary(req.file.buffer, "store/blogs");
      imageUrl      = result.secure_url;
      imagePublicId = result.public_id;
    }

    const blog = await Blog.create({
      supplierId,
      title: title.trim(),
      content: content.trim(),
      excerpt: excerpt?.trim(),
      imageUrl,
      imagePublicId,
      status: "pending",             // always pending for supplier content
    });

    // Notify all admins
    try {
      const admins = await User.find({ role: "Admin" }).select("_id");
      const adminIds = admins.map((a) => a._id);
      if (adminIds.length > 0) {
        await createNotificationForMany({
          userIds: adminIds,
          type: "blog",
          title: "New supplier blog to review",
          message: `Supplier created blog: ${blog.title}`,
          blogId: blog._id,
        });
      }
    } catch (notifyErr) {
      console.error("Supplier blog admin notification error:", notifyErr.message);
    }

    res.status(201).json({ data: blog });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// PUT /api/supplier-dashboard/blogs/:id
exports.updateBlog = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const blog = await Blog.findById(req.params.id);

    if (!blog) return res.status(404).json({ error: "Blog not found" });

    if (!blog.supplierId || blog.supplierId.toString() !== supplierId.toString()) {
      return res.status(403).json({ error: "Not your blog" });
    }

    const { title, content, excerpt } = req.body;
    if (title   !== undefined) blog.title   = title.trim();
    if (content !== undefined) blog.content = content.trim();
    if (excerpt !== undefined) blog.excerpt = excerpt.trim();

    if (req.file) {
      if (blog.imagePublicId) {
        await cloudinary.uploader.destroy(blog.imagePublicId).catch(() => {});
      }
      const result = await uploadToCloudinary(req.file.buffer, "store/blogs");
      blog.imageUrl      = result.secure_url;
      blog.imagePublicId = result.public_id;
    }

    // Editing resets to pending for admin re-review
    blog.status = "pending";
    await blog.save();

    // Notify admins
    try {
      const admins = await User.find({ role: "Admin" }).select("_id");
      const adminIds = admins.map((a) => a._id);
      if (adminIds.length > 0) {
        await createNotificationForMany({
          userIds: adminIds,
          type: "blog",
          title: "Supplier blog updated – needs review",
          message: `Supplier edited blog: ${blog.title}`,
          blogId: blog._id,
        });
      }
    } catch (notifyErr) {
      console.error("Supplier blog update admin notification error:", notifyErr.message);
    }

    res.json({ data: blog });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// DELETE /api/supplier-dashboard/blogs/:id
exports.deleteBlog = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const blog = await Blog.findById(req.params.id);

    if (!blog) return res.status(404).json({ error: "Blog not found" });

    if (!blog.supplierId || blog.supplierId.toString() !== supplierId.toString()) {
      return res.status(403).json({ error: "Not your blog" });
    }

    if (blog.imagePublicId) {
      await cloudinary.uploader.destroy(blog.imagePublicId).catch(() => {});
    }
    await blog.deleteOne();
    res.json({ message: "Blog deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PURCHASES
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/supplier-dashboard/purchases
exports.listPurchases = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const purchases = await Purchase.find({ supplierId })
      .populate("productId", "name category")
      .populate("userId", "username email")
      .sort({ date: -1 });
    res.json({ data: purchases });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/**
 * POST /api/supplier-dashboard/purchases/record
 * Called internally (or by the mobile app booking flow) to record a purchase.
 * Accepts: supplierId (resolved from productId), productId, qte, userId, userInfo, price
 * This endpoint can be called by the User (via verifyToken) or internally.
 */
exports.recordPurchase = async (req, res) => {
  try {
    const { productId, qte, userInfo, price } = req.body;

    if (!productId || !qte) {
      return res.status(400).json({ error: "productId and qte are required" });
    }

    // Resolve supplier from product
    const product = await Product.findById(productId);
    if (!product) return res.status(404).json({ error: "Product not found" });

    const supplierId = product.supplier;
    const userId = req.user?.id || req.user?._id || null;

    // Fetch user info if not provided
    let resolvedUserInfo = userInfo;
    if (!resolvedUserInfo && userId) {
      const user = await User.findById(userId).select("username email");
      if (user) resolvedUserInfo = `${user.username} (${user.email})`;
    }

    const receiptNumber = await getNextReceiptNumber(supplierId);

    const purchase = await Purchase.create({
      supplierId,
      productId,
      article: product.name,
      qte: Number(qte),
      userInfo: resolvedUserInfo || "Unknown",
      userId,
      price: price !== undefined ? Number(price) : product.price * Number(qte),
      receiptNumber,
      date: new Date(),
    });

    // Decrement quantity in product
    await Product.findByIdAndUpdate(productId, {
      $inc: { quantity: -Number(qte) },
    });

    res.status(201).json({ data: purchase });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// GET /api/supplier-dashboard/purchases/:id/receipt
exports.getReceipt = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const purchase = await Purchase.findById(req.params.id)
      .populate("productId", "name category price")
      .populate("userId", "username email");

    if (!purchase) return res.status(404).json({ error: "Purchase not found" });
    if (purchase.supplierId.toString() !== supplierId) {
      return res.status(403).json({ error: "Access denied" });
    }

    const supplier = await Supplier.findById(supplierId).select(
      "shopName email phone location logoUrl"
    );

    const doc = new PDFDocument({ size: "A4", margin: 50 });

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="receipt-${purchase.receiptNumber || purchase._id}.pdf"`
    );
    doc.pipe(res);

    // Header
    doc.fontSize(22).font("Helvetica-Bold").text(supplier?.shopName || "Plantique Shop", { align: "center" });
    doc.fontSize(10).font("Helvetica").fillColor("#666666");
    if (supplier?.email) doc.text(supplier.email, { align: "center" });
    if (supplier?.phone) doc.text(supplier.phone, { align: "center" });
    if (supplier?.location) doc.text(supplier.location, { align: "center" });
    doc.moveDown(0.5);

    // Divider
    doc.strokeColor("#cccccc").lineWidth(1).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.5);

    // Receipt info
    doc.fillColor("#000000").fontSize(12).font("Helvetica-Bold");
    doc.text(`Receipt #: ${purchase.receiptNumber || "N/A"}`);
    doc.font("Helvetica").fontSize(10).fillColor("#333333");
    const dateStr = purchase.date
      ? new Date(purchase.date).toLocaleDateString("en-US", {
          year: "numeric",
          month: "long",
          day: "numeric",
        })
      : "N/A";
    doc.text(`Date: ${dateStr}`);
    doc.text(`Customer: ${purchase.userInfo || "Unknown"}`);
    doc.moveDown(0.5);

    // Divider
    doc.strokeColor("#cccccc").moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.5);

    // Table header
    const tableTop = doc.y;
    const colX = [50, 280, 350, 420, 470];
    doc.fontSize(10).font("Helvetica-Bold").fillColor("#000000");
    doc.text("Article", colX[0], tableTop, { width: 220 });
    doc.text("Qty", colX[1], tableTop, { width: 60, align: "right" });
    doc.text("Unit Price", colX[2], tableTop, { width: 60, align: "right" });
    doc.text("Total", colX[3], tableTop, { width: 60, align: "right" });

    doc.moveDown(0.3);
    doc.strokeColor("#cccccc").moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.3);

    // Table row
    doc.font("Helvetica").fontSize(10).fillColor("#333333");
    const rowY = doc.y;
    const unitPrice = purchase.productId?.price || purchase.price / purchase.qte;
    doc.text(purchase.article || "N/A", colX[0], rowY, { width: 220 });
    doc.text(String(purchase.qte), colX[1], rowY, { width: 60, align: "right" });
    doc.text(`$${unitPrice.toFixed(2)}`, colX[2], rowY, { width: 60, align: "right" });
    doc.text(`$${purchase.price.toFixed(2)}`, colX[3], rowY, { width: 60, align: "right" });

    doc.moveDown(1);
    doc.strokeColor("#cccccc").moveTo(50, doc.y).lineTo(545, doc.y).stroke();
    doc.moveDown(0.5);

    // Grand total
    doc.fontSize(12).font("Helvetica-Bold").fillColor("#000000");
    doc.text(`Grand Total: $${purchase.price.toFixed(2)}`, { align: "right" });

    doc.moveDown(2);

    // Footer
    doc.fontSize(10).font("Helvetica").fillColor("#888888");
    doc.text("Thank you for your purchase!", { align: "center" });

    doc.end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// STATS
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/supplier-dashboard/stats?year=2026
// Returns overview numbers + a month-by-month curve for the requested year
// (defaults to the current year) so the supplier can see which month sold best.
exports.getStats = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const now = new Date();
    const year = parseInt(req.query.year, 10) || now.getFullYear();

    const [totalProducts, purchases] = await Promise.all([
      Product.countDocuments({ supplier: supplierId, isActive: true }),
      Purchase.find({ supplierId }),
    ]);

    const totalPurchases = purchases.length;
    const totalIncome = purchases.reduce((sum, p) => sum + (p.price || 0), 0);

    // Aggregate quantity/revenue per product name to find the best seller
    const salesByProduct = {};
    purchases.forEach((p) => {
      const key = p.article || "Unknown";
      if (!salesByProduct[key]) salesByProduct[key] = { qty: 0, revenue: 0 };
      salesByProduct[key].qty += p.qte || 0;
      salesByProduct[key].revenue += p.price || 0;
    });

    let mostSoldProduct = null;
    let bestQty = -1;
    Object.entries(salesByProduct).forEach(([name, s]) => {
      if (s.qty > bestQty) {
        bestQty = s.qty;
        mostSoldProduct = { name, quantity: s.qty, revenue: s.revenue };
      }
    });

    // Distinct years the supplier has purchases in (for a year picker on the frontend)
    const yearsSet = new Set(purchases.map((p) => new Date(p.date).getFullYear()));
    yearsSet.add(now.getFullYear());
    const availableYears = Array.from(yearsSet).sort((a, b) => b - a);

    // Month-by-month curve (purchase count + income) for the requested year
    const monthlyStats = Array.from({ length: 12 }, (_, i) => ({
      month: i + 1,
      purchases: 0,
      income: 0,
    }));

    purchases.forEach((p) => {
      const d = new Date(p.date);
      if (d.getFullYear() === year) {
        monthlyStats[d.getMonth()].purchases += 1;
        monthlyStats[d.getMonth()].income += p.price || 0;
      }
    });

    res.json({
      data: {
        totalProducts,
        totalPurchases,
        totalIncome,
        mostSoldProduct, // { name, quantity, revenue } or null if no sales yet
        year,
        availableYears,
        monthlyStats, // [{ month: 1..12, purchases, income }]
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/supplier-dashboard/me  — returns current supplier profile
exports.getProfile = async (req, res) => {
  try {
    const supplierId = req.user.supplierId;
    const supplier = await Supplier.findById(supplierId);
    if (!supplier) return res.status(404).json({ error: "Supplier not found" });
    res.json({ data: supplier });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};