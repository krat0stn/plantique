/**
 * Migration script: Merge User + Supplier collections into a unified Account collection.
 *
 * Usage:
 *   node scripts/migrate-to-account.js          (dry-run by default)
 *   node scripts/migrate-to-account.js --apply   (actually write changes)
 *
 * Safety:
 *   - Preserves original _id values so existing JWTs and refs stay valid.
 *   - Checks for email collisions before migrating.
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

// Old collection names (raw MongoDB collections)
const USERS = "users";
const SUPPLIERS = "suppliers";
const ACCOUNTS = "accounts";

// Ref targets that need updating
const REF_MODELS = {
  postes: { authorFields: ["userId", "supplierId"], mentionsFields: ["mentions"] },
  blogs: { authorFields: ["author", "supplierId"], mentionsFields: [] },
  comments: { authorFields: ["userId", "supplierId"], mentionsFields: ["mentions"] },
  products: { supplierFields: ["supplier"] },
  purchases: { supplierFields: ["supplierId"], userFields: ["userId"] },
  notifications: { userFields: ["user", "fromUser"] },
  likes: { userFields: ["userId"] },
  saves: { userFields: ["userId"] },
  reviews: { userFields: ["user"] },
};

async function run() {
  console.log(`\nMigration mode: ${APPLY ? "APPLY (writing changes)" : "DRY RUN (no changes)"}\n`);

  await mongoose.connect(MONGO_URI);
  const db = mongoose.connection.db;

  // ── Step 1: Check for existing accounts collection ──────────────────────
  const collections = await db.listCollections({ name: ACCOUNTS }).toArray();
  if (collections.length > 0) {
    const count = await db.collection(ACCOUNTS).countDocuments();
    if (count > 0) {
      console.error(`ERROR: "${ACCOUNTS}" collection already exists with ${count} documents. Aborting.`);
      await mongoose.disconnect();
      process.exit(1);
    }
  }

  // ── Step 2: Migrate Users → Accounts ────────────────────────────────────
  const users = await db.collection(USERS).find({}).toArray();
  console.log(`Found ${users.length} users to migrate.`);

  const accounts = [];
  const emailSet = new Set();

  for (const u of users) {
    if (emailSet.has(u.email)) {
      console.error(`  SKIP: Duplicate user email "${u.email}" (id: ${u._id})`);
      continue;
    }
    emailSet.add(u.email);

    accounts.push({
      _id: u._id,
      email: u.email,
      password: u.password || null,
      role: u.role || "User",
      picture: u.picture || null,
      status: u.status || "Active",
      username: u.username || null,
      resetCode: u.resetCode || null,
      resetCodeExpires: u.resetCodeExpires || null,
      // Supplier fields left null for users
      firstName: null,
      lastName: null,
      shopName: null,
      shopType: null,
      phone: null,
      location: null,
      bio: "",
      logoUrl: null,
      logoPublicId: null,
      isActive: u.status !== "Inactive",
      subscriptionStart: null,
      subscriptionEnd: null,
      createdAt: u.createdAt,
      updatedAt: u.updatedAt,
    });
  }

  // ── Step 3: Migrate Suppliers → Accounts ────────────────────────────────
  const suppliers = await db.collection(SUPPLIERS).find({}).toArray();
  console.log(`Found ${suppliers.length} suppliers to migrate.`);

  for (const s of suppliers) {
    if (emailSet.has(s.email)) {
      console.error(`  SKIP: Duplicate supplier email "${s.email}" (id: ${s._id}) — email already in accounts`);
      continue;
    }
    emailSet.add(s.email);

    const username = `${s.firstName || ""} ${s.lastName || ""}`.trim() || s.shopName || "Supplier";

    accounts.push({
      _id: s._id,
      email: s.email,
      password: s.password || null,
      role: "Supplier",
      picture: s.logoUrl || null,
      status: s.isActive !== false ? "Active" : "Inactive",
      username,
      resetCode: null,
      resetCodeExpires: null,
      firstName: s.firstName || null,
      lastName: s.lastName || null,
      shopName: s.shopName || null,
      shopType: s.shopType || null,
      phone: s.phone || null,
      location: s.location || null,
      bio: s.bio || "",
      logoUrl: s.logoUrl || null,
      logoPublicId: s.logoPublicId || null,
      isActive: s.isActive !== false,
      subscriptionStart: s.subscriptionStart || null,
      subscriptionEnd: s.subscriptionEnd || null,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    });
  }

  console.log(`\nTotal accounts to insert: ${accounts.length}`);

  if (APPLY) {
    // Create accounts collection
    await db.createCollection(ACCOUNTS);
    if (accounts.length > 0) {
      await db.collection(ACCOUNTS).insertMany(accounts, { ordered: false });
    }
    console.log("✓ Accounts collection created and populated.");
  } else {
    console.log("  (dry run — no writes)");
  }

  // ── Step 4: Migrate author fields in content collections ────────────────
  for (const [collection, config] of Object.entries(REF_MODELS)) {
    const col = db.collection(collection);
    const count = await col.countDocuments();
    if (count === 0) continue;

    console.log(`\nMigrating "${collection}" (${count} docs)...`);

    // Migrate author fields: pick the first non-null from authorFields → authorId
    if (config.authorFields) {
      for (const fieldName of config.authorFields) {
        if (fieldName === "userId" || fieldName === "author") {
          // These map to authorId
          const docs = await col.find({ [fieldName]: { $ne: null } }).toArray();
          console.log(`  ${fieldName}: ${docs.length} docs → authorId`);
          if (APPLY && docs.length > 0) {
            for (const doc of docs) {
              await col.updateOne(
                { _id: doc._id },
                { $set: { authorId: doc[fieldName] }, $unset: { [fieldName]: "" } }
              );
            }
          }
        } else if (fieldName === "supplierId") {
          // supplierId maps to authorId (if authorId not already set)
          const docs = await col.find({
            supplierId: { $ne: null },
            $or: [{ authorId: { $exists: false } }, { authorId: null }],
          }).toArray();
          console.log(`  ${fieldName}: ${docs.length} docs → authorId (fallback)`);
          if (APPLY && docs.length > 0) {
            for (const doc of docs) {
              await col.updateOne(
                { _id: doc._id },
                { $set: { authorId: doc.supplierId }, $unset: { supplierId: "" } }
              );
            }
          }
          // Clean up remaining supplierId if authorId was already set
          if (APPLY) {
            await col.updateMany(
              { supplierId: { $exists: true } },
              { $unset: { supplierId: "" } }
            );
          }
        }
      }
    }

    // Migrate supplier references in products/purchases
    if (config.supplierFields) {
      for (const fieldName of config.supplierFields) {
        const renameTo = fieldName === "supplier" ? "sellerId" : "sellerId";
        const docs = await col.find({ [fieldName]: { $ne: null } }).toArray();
        console.log(`  ${fieldName}: ${docs.length} docs → ${renameTo}`);
        if (APPLY && docs.length > 0) {
          await col.updateMany(
            { [fieldName]: { $exists: true } },
            [{ $set: { [renameTo]: `$${fieldName}` } }, { $unset: fieldName }]
          );
        }
      }
    }

    // Migrate user references in purchases (userId → buyerId)
    if (config.userFields && collection === "purchases") {
      const docs = await col.find({ userId: { $ne: null } }).toArray();
      console.log(`  userId: ${docs.length} docs → buyerId`);
      if (APPLY && docs.length > 0) {
        await col.updateMany(
          { userId: { $exists: true } },
          [{ $set: { buyerId: "$userId" } }, { $unset: "userId" }]
        );
      }
    }

    // Migrate mentions arrays (ref "User" → ref "Account" — IDs stay the same)
    if (config.mentionsFields) {
      for (const fieldName of config.mentionsFields) {
        const docs = await col.find({ [fieldName]: { $exists: true, $ne: [] } }).countDocuments();
        console.log(`  ${fieldName}: ${docs} docs (IDs unchanged, ref updated in schema)`);
      }
    }

    // Migrate user refs in notifications/likes/saves/reviews (field names stay, only ref target changes)
    if (config.userFields && collection !== "purchases") {
      for (const fieldName of config.userFields) {
        const docs = await col.find({ [fieldName]: { $ne: null } }).countDocuments();
        console.log(`  ${fieldName}: ${docs} docs (IDs unchanged, ref updated in schema)`);
      }
    }
  }

  // ── Step 5: Create indexes on accounts ──────────────────────────────────
  if (APPLY) {
    await db.collection(ACCOUNTS).createIndex({ email: 1 }, { unique: true });
    await db.collection(ACCOUNTS).createIndex({ username: 1 }, { sparse: true });
    await db.collection(ACCOUNTS).createIndex({ shopName: 1 }, { sparse: true });
    await db.collection(ACCOUNTS).createIndex({ role: 1, createdAt: -1 });
    console.log("\n✓ Indexes created on accounts collection.");
  }

  // ── Step 6: Validation ──────────────────────────────────────────────────
  console.log("\n── Validation ──");
  if (APPLY) {
    const orphanPosts = await db.collection("postes").countDocuments({
      authorId: { $ne: null },
      $expr: { $not: { $in: ["$authorId", { $map: { input: { $objectToArray: { a: 1 } }, as: "x", in: "$$x.v" } }] } },
    });
    // Simpler validation: check authorId values exist in accounts
    const allAuthorIds = await db.collection("postes").distinct("authorId", { authorId: { $ne: null } });
    const existingAccounts = await db.collection(ACCOUNTS).countDocuments({ _id: { $in: allAuthorIds } });
    console.log(`  Posts with authorId: ${allAuthorIds.length} unique authors, ${existingAccounts} found in accounts`);

    if (existingAccounts < allAuthorIds.length) {
      console.error(`  WARNING: ${allAuthorIds.length - existingAccounts} orphaned author references!`);
    } else {
      console.log("  ✓ All post author references valid.");
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
