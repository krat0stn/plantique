// app.js
require("dotenv").config();



const path = require("path");
const http = require("http");
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const cookieParser = require("cookie-parser");

// ── Routes ───────────────────────────────────────────────────────────────────
const authRoutes = require("./routes/authRoutes");
const userRoutes = require("./routes/userRoute");
const posteRoutes = require("./routes/posteRoutes");
const adminPosteRoutes = require("./routes/adminPosteRoutes");
const blogRoutes = require("./routes/BlogRoutes");
const adminBlogRoutes = require("./routes/adminBlogRoutes");
const reviewRoutes = require("./routes/reviewRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const diagnosisRoutes = require("./routes/diagnosisRoutes");
const recognitionRoutes = require("./routes/recognitionRoutes");
const identificationRoutes = require("./routes/identificationRoutes");
const recommendationRoutes = require("./routes/recommendationRoutes");
const plantCareRoutes = require("./routes/plantCareRoutes");
const reminderRoutes = require("./routes/reminderRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const arRoutes = require("./routes/arRoutes");
const adminPlantCareRoutes = require("./routes/adminPlantCareRoutes");
const storeRoutes    = require("./routes/productRoutes");
const supplierRoutes = require("./routes/supplierRoutes");
const supplierDashboardRoutes = require("./routes/supplierDashboardRoutes");

const app = express();
const server = http.createServer(app);

const { init } = require("./socket");
init(server);

app.set("trust proxy", 1);

app.use(
  cors({
    origin: '*',
    methods: ["GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);
app.use(cookieParser());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

app.use("/storages", express.static(path.resolve(process.cwd(), "storages")));

const mongoUri = process.env.MONGO_URI;
if (!mongoUri) {
  console.error(" MONGO_URI is not set in environment.");
  process.exit(1);
}

mongoose
  .connect(mongoUri)
  .then(() => console.log(" MongoDB connected"))
  .catch((err) => {
    console.error(" MongoDB connection error:", err);
    process.exit(1);
  });

app.get("/api/health", (_req, res) =>
  res.status(200).json({ status: "ok", time: new Date().toISOString() }),
);

app.use("/api/auth", authRoutes);
app.use("/api/blogs", blogRoutes);

app.use("/api/users", userRoutes);
app.use("/api/postes", posteRoutes);
app.use("/api/reviews", reviewRoutes);
app.use("/api/diagnosis", diagnosisRoutes);
app.use("/api/recognition", recognitionRoutes);
app.use("/api/ar", arRoutes);
app.use("/api/identifications", identificationRoutes);
app.use("/api/disease", recommendationRoutes);
app.use("/api/plant-care", plantCareRoutes);
app.use("/api/reminders", reminderRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/admin/plant-care", adminPlantCareRoutes);

app.use("/api/admin/blogs", adminBlogRoutes);
app.use("/api/admin/postes", adminPosteRoutes);
app.use("/api/admin/dashboard", dashboardRoutes);

app.use("/api/store",     storeRoutes);
app.use("/api/suppliers", supplierRoutes);
app.use("/api/supplier-dashboard", supplierDashboardRoutes);

// Purchase record — called by user-side booking flow (requires any valid token)
(function () {
  const purchaseRouter = require("express").Router();
  const { verifyToken } = require("./middlewares/authMiddleware");
  const { recordPurchase } = require("./controllers/supplierDashboardController");
  purchaseRouter.post("/record", verifyToken, recordPurchase);
  app.use("/api/purchases", purchaseRouter);
})();

app.use((_req, res) => {
  res.status(404).json({ errormessage: "Route introuvable" });
});

app.use((err, _req, res, _next) => {
  console.error("Unhandled error:", err);
  res
    .status(err.status || 500)
    .json({ errormessage: err.message || "Erreur serveur" });
});

const PORT = process.env.PORT || 4000;
server.listen(PORT, "0.0.0.0", () =>
  console.log(` API listening at http://0.0.0.0:${PORT}`),
);

process.on("unhandledRejection", (reason) => {
  console.error("Unhandled Rejection:", reason);
});
process.on("uncaughtException", (err) => {
  console.error("Uncaught Exception:", err);
});