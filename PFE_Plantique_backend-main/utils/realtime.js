const { getIO } = require("../socket");

exports.notifyBlogNew = (blog) => {
  const io = getIO();
  io.to("admins").emit("blog:new", {
    blogId: blog._id,
    title: blog.title,
    author: blog.author?.username || blog.author?.name || blog.author || "",
    createdAt: blog.createdAt,
    cover: blog.imageUrl || blog.image || blog.cover || null,
  });
};

exports.notifyPostNew = (post) => {
  const io = getIO();
  io.emit("post:new", {
    postId: post._id,
    user: post.user?.username || post.user?.email || post.user || "",
    content: post.content?.slice(0, 120) || "",
    picture: post.picture || null,
    createdAt: post.createdAt,
  });
};

exports.notifyPostLike = (post, likedByUser) => {
  const io = getIO();
  // Option 1: notify everyone
  // io.emit("post:like", {
  //  postId: post._id,
  //  likesCount: post.likesCount,
  //  by: likedByUser?.username || likedByUser?.email || likedByUser || "",
  // });
  // Option 2 (room-based): notify only post owner
  io.to(`user:${post.userId}`).emit("post:like", {
    postId: post._id,
    likesCount: post.likesCount,
    by: likedByUser?.username || likedByUser?.email || likedByUser || "",
  });
};

exports.notifyPostComment = (post, comment) => {
  const io = getIO();
  io.emit("post:comment", {
    postId: post._id,
    commentId: comment._id,
    text: comment.text?.slice(0, 140) || "",
    by: comment.user?.username || comment.user?.email || comment.user || "",
    createdAt: comment.createdAt,
  });
};
