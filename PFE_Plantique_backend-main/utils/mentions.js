// utils/mentions.js
const User = require("../models/User");

/**
 * Extract @usernames from text content.
 * Returns an array of unique lowercase usernames (without the @).
 */
function extractMentionUsernames(content) {
  if (!content) return [];
  const matches = content.match(/@(\w+)/g);
  if (!matches) return [];
  const usernames = [...new Set(matches.map((m) => m.slice(1).toLowerCase()))];
  return usernames;
}

/**
 * Given an array of usernames, find the corresponding User IDs.
 * Returns an array of ObjectId strings.
 */
async function resolveMentionIds(usernames) {
  if (!usernames || usernames.length === 0) return [];
  const users = await User.find({
    username: { $in: usernames.map((u) => new RegExp(`^${u}$`, "i")) },
  }).select("_id");
  return users.map((u) => u._id);
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
