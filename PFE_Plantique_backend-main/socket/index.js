// socket/index.js
const { Server } = require("socket.io");

let io;

function init(server) {
  const allowedOrigins = process.env.SOCKET_ORIGINS
    ? process.env.SOCKET_ORIGINS.split(",").map((o) => o.trim())
    : ["http://localhost:5173", "http://localhost:4000"];

  io = new Server(server, {
    cors: {
      origin: allowedOrigins,
      credentials: true,
    },
    path: "/socket.io",
  });

  io.on("connection", (socket) => {
    const auth = socket.handshake.auth || {};
    const userId = auth.userId;
    const role = auth.role;

    if (userId) socket.join(`user:${userId}`);
    if (role === "Admin") socket.join("admins");

    console.log("socket connected", socket.id, { userId, role });

    socket.on("disconnect", () => {
      console.log("socket disconnected", socket.id);
    });
  });

  return io;
}

function getIO() {
  if (!io) throw new Error("Socket.io not initialized yet!");
  return io;
}

module.exports = { init, getIO };
