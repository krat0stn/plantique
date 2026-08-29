// utils/mentions.js
const Account = require("../models/Account");

/**
 * Extract @usernames from text content.
 * Captures @word handles (no spaces) used for mentions.
 * Returns an array of unique lowercase handles (without the @).
 */
function extractMentionUsernames(content) {
  if (!content) return [];
  const matches = content.match(/@(\w+)/g);
  if (!matches) return [];
  const usernames = [...new Set(matches.map((m) => m.slice(1).toLowerCase()))];
  return usernames;
}

/**
 * Given an array of handles (e.g. "ilyes_ilyes"), find the corresponding Account IDs.
 * Converts underscores back to spaces for matching against stored usernames.
 * Returns an array of ObjectId strings.
 */
async function resolveMentionIds(usernames) {
  if (!usernames || usernames.length === 0) return [];
  // Build a query that matches both exact handles and space-separated versions
  const conditions = [];
  for (const u of usernames) {
    // Match the handle as-is (for regular users like "ahmed_ahmed")
    conditions.push({ username: { $regex: new RegExp(`^${escapeRegex(u)}$`), $options: "i" } });
    // Also match with underscores converted to spaces (for suppliers like "ilyes ilyes")
    const spaced = u.replace(/_/g, " ");
    if (spaced !== u) {
      conditions.push({ username: { $regex: new RegExp(`^${escapeRegex(spaced)}$`), $options: "i" } });
    }
  }
  const accounts = await Account.find({ $or: conditions }).select("_id");
  return accounts.map((a) => a._id);
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Send notification to each mentioned user (excluding the actor).
 */
async function notifyMentionedUsers({
  mentionedIds,
  actorUserId,
  postId,
  actorName,
  contextType,
}) {
  const { createNotification } = require("../controllers/notificationController");
  for (const uid of mentionedIds) {
    if (String(uid) === String(actorUserId)) continue;
    try {
      await createNotification({
        userId: uid,
        type: "mention",
        title: `You were mentioned in a ${contextType}`,
        message: `${actorName} mentioned you in a ${contextType}.`,
        postId,
      });
    } catch (err) {
      console.error("Mention notification error:", err.message);
    }
  }
}

module.exports = {
  extractMentionUsernames,
  resolveMentionIds,
  notifyMentionedUsers,
};
