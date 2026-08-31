/**
 * Migration script: Extract supplier-specific fields from accounts into a separate suppliers collection.
 *
 * Usage:
 *   node scripts/migrate-supplier-data.js          (dry-run by default)
 *   node scripts/migrate-supplier-data.js --apply   (actually write changes)
 *
 * Safety:
 *   - Preserves original account _id values.
 *   - Creates suppliers collection with accountId reference to accounts.
 *   - Reports all changes before writing (dry-run).
 */

require("dotenv").config();
const mongoose = require("mongoose");

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) {
  console.error("MONGO_URI is not set in .env");
  process.exit(1);
}

const APPLY = process.argv.includes("--apply");

const ACCOUNTS = "accounts";
const SUPPLIERS = "suppliers";

async function run() {
  console.log(`\nMigration mode: ${APPLY ? "APPLY (writing changes)" : "DRY RUN (no changes)"}\n`);

  await mongoose.connect(MONGO_URI);
  const db = mongoose.connection.db;

  // ── Step 1: Check accounts collection exists ──────────────────────────
  const accountsCollection = await db.listCollections({ name: ACCOUNTS }).toArray();
  if (accountsCollection.length === 0) {
    console.error(`ERROR: "${ACCOUNTS}" collection does not exist. Aborting.`);
    await mongoose.disconnect();
    process.exit(1);
  }

  // ── Step 2: Find all supplier accounts ────────────────────────────────
  const supplierAccounts = await db.collection(ACCOUNTS).find({ role: "Supplier" }).toArray();
  console.log(`Found ${supplierAccounts.length} supplier accounts to migrate.`);

  if (supplierAccounts.length === 0) {
    console.log("No suppliers to migrate. Exiting.");
    await mongoose.disconnect();
    process.exit(0);
  }

  // ── Step 3: Check if suppliers collection already has data ────────────
  const suppliersCollection = await db.listCollections({ name: SUPPLIERS }).toArray();
  if (suppliersCollection.length > 0) {
    const existingCount = await db.collection(SUPPLIERS).countDocuments();
    if (existingCount > 0) {
      console.error(`ERROR: "${SUPPLIERS}" collection already exists with ${existingCount} documents. Aborting.`);
      await mongoose.disconnect();
      process.exit(1);
    }
  }

  // ── Step 4: Create supplier documents ─────────────────────────────────
  const supplierDocs = [];
  const accountUpdates = [];

  for (const account of supplierAccounts) {
    // Create supplier document
    supplierDocs.push({
      accountId: account._id,
      firstName: account.firstName || null,
      lastName: account.lastName || null,
      shopName: account.shopName || null,
      shopType: account.shopType || null,
      phone: account.phone || null,
      location: account.location || null,
      bio: account.bio || "",
      logoUrl: account.logoUrl || null,
      logoPublicId: account.logoPublicId || null,
      isActive: account.isActive !== false,
      subscriptionStart: account.subscriptionStart || null,
      subscriptionEnd: account.subscriptionEnd || null,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    });

    // Mark account for cleanup (remove supplier-specific fields)
    accountUpdates.push({
      updateOne: {
        filter: { _id: account._id },
        update: {
          $unset: {
            firstName: "",
            lastName: "",
            shopName: "",
            shopType: "",
            phone: "",
            location: "",
            bio: "",
            logoUrl: "",
            logoPublicId: "",
            isActive: "",
            subscriptionStart: "",
            subscriptionEnd: "",
          },
        },
      },
    });
  }

  console.log(`\nSupplier documents to create: ${supplierDocs.length}`);
  console.log(`Account documents to update: ${accountUpdates.length}`);

  if (APPLY) {
    // Create suppliers collection
    if (suppliersCollection.length === 0) {
      await db.createCollection(SUPPLIERS);
    }

    // Insert supplier documents
    if (supplierDocs.length > 0) {
      await db.collection(SUPPLIERS).insertMany(supplierDocs, { ordered: false });
      console.log("✓ Suppliers collection created and populated.");
    }

    // Update accounts to remove supplier-specific fields
    if (accountUpdates.length > 0) {
      await db.collection(ACCOUNTS).bulkWrite(accountUpdates);
      console.log("✓ Supplier-specific fields removed from accounts.");
    }

    // Create indexes on suppliers collection
    await db.collection(SUPPLIERS).createIndex({ accountId: 1 }, { unique: true });
    await db.collection(SUPPLIERS).createIndex({ shopName: 1 }, { sparse: true });
    console.log("✓ Indexes created on suppliers collection.");
  } else {
    console.log("  (dry run — no writes)");
  }

  // ── Step 5: Validation ──────────────────────────────────────────────────
  console.log("\n── Validation ──");
  if (APPLY) {
    // Verify all suppliers have corresponding accounts
    const supplierAccountIds = supplierDocs.map((s) => s.accountId);
    const existingAccounts = await db.collection(ACCOUNTS).countDocuments({
      _id: { $in: supplierAccountIds },
      role: "Supplier",
    });
    console.log(`  Suppliers with valid accounts: ${existingAccounts}/${supplierAccountIds.length}`);

    if (existingAccounts < supplierAccountIds.length) {
      console.error(`  WARNING: ${supplierAccountIds.length - existingAccounts} orphaned supplier references!`);
    } else {
      console.log("  ✓ All supplier references valid.");
    }

    // Verify accounts no longer have supplier-specific fields
    const accountsWithSupplierFields = await db.collection(ACCOUNTS).countDocuments({
      role: "Supplier",
      $or: [
        { firstName: { $exists: true } },
        { shopName: { $exists: true } },
        { logoUrl: { $exists: true } },
      ],
    });
    if (accountsWithSupplierFields > 0) {
      console.error(`  WARNING: ${accountsWithSupplierFields} accounts still have supplier fields!`);
    } else {
      console.log("  ✓ All accounts cleaned of supplier-specific fields.");
    }
  }

  console.log("\nMigration complete.");
  await mongoose.disconnect();
}

run().catch((err) => {
  console.error("Migration failed:", err);
  mongoose.disconnect();
  process.exit(1);
});
