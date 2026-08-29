import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'mention_widgets.dart';

const _kStatusColors = {
  'pending': Color(0xFFFFF3CD),
  'approved': Color(0xFFD4EDDA),
  'declined': Color(0xFFF8D7DA),
};
const _kStatusTextColors = {
  'pending': Color(0xFF856404),
  'approved': Color(0xFF155724),
  'declined': Color(0xFF721C24),
};

class SupplierPostModel {
  final String id;
  final String content;
  final String picture;
  final String status;
  final int likesCount;
  final int commentsCount;
  final int savedCount;
  final DateTime createdAt;

  SupplierPostModel({
    required this.id,
    required this.content,
    required this.picture,
    required this.status,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.savedCount = 0,
    required this.createdAt,
  });

  factory SupplierPostModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return SupplierPostModel(
      id: json['_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      savedCount: (json['savedCount'] as num?)?.toInt() ?? 0,
      createdAt: parsedDate,
    );
  }
}

class PostComment {
  final String id;
  final String content;
  final String authorName;
  final String authorPicture;
  final String? parentId;
  final DateTime createdAt;
  final List<PostComment> replies;

  PostComment({
    required this.id,
    required this.content,
    required this.authorName,
    required this.authorPicture,
    this.parentId,
    required this.createdAt,
    this.replies = const [],
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final rawReplies = json['replies'];
    final repliesList = rawReplies is List
        ? rawReplies.map((r) => PostComment.fromJson(r)).toList()
        : <PostComment>[];
    return PostComment(
      id: json['_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Unknown',
      authorPicture: json['authorPicture']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      createdAt: parsedDate,
      replies: repliesList,
    );
  }
}

class SupplierPostsPage extends StatefulWidget {
  const SupplierPostsPage({super.key});

  @override
  State<SupplierPostsPage> createState() => _SupplierPostsPageState();
}

class _SupplierPostsPageState extends State<SupplierPostsPage> {
  List<SupplierPostModel> posts = [];
  List<SupplierPostModel> mentionedPosts = [];
  final Set<String> _hiddenPostIds = {};
  bool _showHidden = false;
  final TextEditingController _mentionedSearchCtrl = TextEditingController();
  String _mentionedQuery = '';
  bool loading = true;
  bool loadingMentioned = false;
  String? error;
  String? errorMentioned;
  int _selectedTab = 0;
  PlatformFile? selectedImage;

  @override
  void initState() {
    super.initState();
    loadPosts();
    loadMentionedPosts();
  }

  Future<void> loadPosts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await ApiService.get('/supplier-dashboard/posts');
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        posts = list.map((p) => SupplierPostModel.fromJson(p)).toList();
      });
    } catch (e) {
      setState(() => error = 'Failed to load posts: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> loadMentionedPosts() async {
    setState(() {
      loadingMentioned = true;
      errorMentioned = null;
    });
    try {
      final data = await ApiService.getMentionedPosts();
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        mentionedPosts = list.map((p) => SupplierPostModel.fromJson(p)).toList();
      });
    } catch (e) {
      setState(() => errorMentioned = 'Failed to load mentioned posts: $e');
    } finally {
      setState(() => loadingMentioned = false);
    }
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => selectedImage = result.files.first);
  }

  List<http.MultipartFile> _buildFiles() {
    if (selectedImage == null) return [];
    return [
      http.MultipartFile.fromBytes(
        'picture',
        selectedImage!.bytes!,
        filename: selectedImage!.name,
      ),
    ];
  }

  Future<void> createPost({required String content}) async {
    try {
      await ApiService.multipartRequest('POST', '/supplier-dashboard/posts', {
        'content': content,
      }, _buildFiles());
      selectedImage = null;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created — pending admin review')),
        );
      await loadPosts();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> updatePost(String postId, {required String content}) async {
    try {
      await ApiService.multipartRequest(
        'PUT',
        '/supplier-dashboard/posts/$postId',
        {'content': content},
        _buildFiles(),
      );
      selectedImage = null;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated — returned to pending review'),
          ),
        );
      await loadPosts();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> deletePost(SupplierPostModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text(
          'Delete this post? This cannot be undone.\n\n"${p.content.substring(0, p.content.length.clamp(0, 80))}..."',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.delete('/supplier-dashboard/posts/${p.id}');
      setState(() => posts.removeWhere((x) => x.id == p.id));
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post deleted')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCommentsDialog(SupplierPostModel post) async {
    List<PostComment> comments = [];
    bool loadingComments = true;
    String? commentError;

    try {
      final data = await ApiService.get(
        '/supplier-dashboard/posts/${post.id}/comments',
      );
      final List<dynamic> list = data['data'] ?? [];
      comments = list.map((c) => PostComment.fromJson(c)).toList();
      loadingComments = false;
    } catch (e) {
      commentError = 'Failed to load comments: $e';
      loadingComments = false;
    }

    if (!mounted) return;

    final commentCtrl = TextEditingController();
    String? replyingToId;
    String? replyingToName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> refreshComments() async {
            try {
              final data = await ApiService.get(
                '/supplier-dashboard/posts/${post.id}/comments',
              );
              final List<dynamic> list = data['data'] ?? [];
              setDialogState(() {
                comments =
                    list.map((c) => PostComment.fromJson(c)).toList();
              });
            } catch (_) {}
          }

          Future<void> refreshPostAndComments() async {
            await refreshComments();
            await loadPosts();
          }

          Future<void> addComment() async {
            final text = commentCtrl.text.trim();
            if (text.isEmpty) return;
            try {
              await ApiService.post(
                '/supplier-dashboard/posts/${post.id}/comments',
                {'content': text},
              );
              commentCtrl.clear();
              replyingToId = null;
              replyingToName = null;
              await refreshPostAndComments();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          }

          Future<void> replyToComment(
              String parentId, String parentName) async {
            final text = commentCtrl.text.trim();
            if (text.isEmpty) return;
            try {
              await ApiService.post(
                '/supplier-dashboard/posts/${post.id}/comments',
                {'content': text, 'parentId': parentId},
              );
              commentCtrl.clear();
              replyingToId = null;
              replyingToName = null;
              await refreshPostAndComments();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          }

          Future<void> deleteComment(String commentId) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Text('Delete comment?'),
                content: const Text('This will also delete all replies to this comment.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (confirm != true) return;
            try {
              await ApiService.delete(
                '/supplier-dashboard/posts/${post.id}/comments/$commentId',
              );
              await refreshPostAndComments();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          }

          Widget buildCommentTile(PostComment c, {bool isReply = false}) {
            return Container(
              margin: EdgeInsets.only(
                left: isReply ? 32 : 0,
                top: 2,
                bottom: 2,
              ),
              decoration: isReply
                  ? BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.green.shade300,
                          width: 2,
                        ),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: isReply ? 12 : 14,
                          backgroundColor: isReply
                              ? Colors.green.shade50
                              : Colors.green.shade100,
                          child: c.authorPicture.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    c.authorPicture,
                                    width: isReply ? 24 : 28,
                                    height: isReply ? 24 : 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      c.authorName.isNotEmpty
                                          ? c.authorName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          fontSize: isReply ? 10 : 12),
                                    ),
                                  ),
                                )
                              : Text(
                                  c.authorName.isNotEmpty
                                      ? c.authorName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      fontSize: isReply ? 10 : 12),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.authorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isReply ? 11 : 13,
                                ),
                              ),
                              Text(
                                '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 38, bottom: 2),
                    child: buildHighlightedText(
                      c.content,
                      fontSize: isReply ? 12 : 13,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 38, bottom: 4),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              replyingToId = c.id;
                              replyingToName = c.authorName;
                            });
                          },
                          icon: const Icon(Icons.reply, size: 13),
                          label: const Text('Reply',
                              style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => deleteComment(c.id),
                          icon: const Icon(Icons.delete_outline,
                              size: 13, color: Colors.red),
                          label: const Text('Delete',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nested replies
                  if (c.replies.isNotEmpty)
                    ...c.replies.map((r) => buildCommentTile(r, isReply: true)),
                ],
              ),
            );
          }

          return AlertDialog(
            title: Text('Comments (${post.commentsCount})'),
            content: SizedBox(
              width: 550,
              height: 500,
              child: Column(
                children: [
                  // Comment input area
                  if (post.status == 'approved') ...[
                    if (replyingToId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply,
                                size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Replying to $replyingToName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setDialogState(() {
                                  replyingToId = null;
                                  replyingToName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: MentionTextField(
                            controller: commentCtrl,
                            hintText: replyingToId != null
                                ? 'Write a reply... (use @ to mention)'
                                : 'Write a comment... (use @ to mention)',
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) {
                              if (replyingToId != null) {
                                replyToComment(
                                    replyingToId!, replyingToName!);
                              } else {
                                addComment();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            if (replyingToId != null) {
                              replyToComment(
                                  replyingToId!, replyingToName!);
                            } else {
                              addComment();
                            }
                          },
                          icon: const Icon(Icons.send, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 6),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Comments are only available for approved posts.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.brown),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Comments list
                  Expanded(
                    child: loadingComments
                        ? const Center(child: CircularProgressIndicator())
                        : commentError != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(commentError,
                                        style: const TextStyle(
                                            color: Colors.red)),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: refreshPostAndComments,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : comments.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No comments yet.',
                                      style: TextStyle(
                                          color: Colors.grey),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: comments.length,
                                    separatorBuilder: (_, __) =>
                                        Divider(
                                            height: 1,
                                            color:
                                                Colors.grey.shade200),
                                    itemBuilder: (ctx, i) {
                                      return buildCommentTile(
                                          comments[i]);
                                    },
                                  ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLikesDialog(SupplierPostModel post) async {
    List<Map<String, dynamic>> likes = [];
    bool loadingLikes = true;

    try {
      final data = await ApiService.get('/postes/${post.id}/likes');
      final List<dynamic> list = data['data'] ?? [];
      likes = list.cast<Map<String, dynamic>>();
      loadingLikes = false;
    } catch (e) {
      loadingLikes = false;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Likes (${post.likesCount})'),
        content: SizedBox(
          width: 400,
          height: 350,
          child: loadingLikes
              ? const Center(child: CircularProgressIndicator())
              : likes.isEmpty
                  ? const Center(
                      child: Text('No likes yet.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.separated(
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final like = likes[i];
                        final user = like['userId'] is Map
                            ? like['userId']
                            : {};
                        final username =
                            user['username']?.toString() ?? 'Unknown';
                        final picture =
                            user['picture']?.toString() ?? '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.red.shade50,
                            child: picture.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      picture,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                        username.isNotEmpty
                                            ? username[0].toUpperCase()
                                            : '?',
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                : Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPostDialog({SupplierPostModel? post}) {
    final contentCtrl = TextEditingController(text: post?.content ?? '');
    selectedImage = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(post == null ? 'New Post' : 'Edit Post'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post == null) ...[
                    // Info banner for new posts
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'New posts require admin approval before they are published.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ElevatedButton.icon(
                    onPressed: () async {
                      await pickImage();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.image),
                    label: Text(
                      selectedImage == null
                          ? 'Attach image (optional)'
                          : 'Image: ${selectedImage!.name}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  MentionTextField(
                    controller: contentCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Content *',
                      hintText: 'Write your post... (use @ to mention users)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Content is required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                if (post == null) {
                  await createPost(content: contentCtrl.text.trim());
                } else {
                  await updatePost(post.id, content: contentCtrl.text.trim());
                }
              },
              child: Text(post == null ? 'Post' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kStatusColors[status] ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _kStatusTextColors[status] ?? Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Posts',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    loadPosts();
                    loadMentionedPosts();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                if (_selectedTab == 0)
                  ElevatedButton.icon(
                    onPressed: () => _showPostDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Post'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTab(0, 'My Posts', Icons.person),
                const SizedBox(width: 8),
                _buildTab(1, 'Mentioned', Icons.alternate_email),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedTab == 0) ...[
              if (loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: loadPosts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (posts.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No posts yet. Click "New Post" to create one.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color.fromARGB(
                              186,
                              234,
                              143,
                              143,
                            ).withValues(alpha: 0.3),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Content',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Likes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Comments',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: posts.map((p) {
                            final preview = p.content.length > 80
                                ? '${p.content.substring(0, 80)}…'
                                : p.content;
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: buildHighlightedText(
                                      preview,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataCell(_statusBadge(p.status)),
                                DataCell(
                                  InkWell(
                                    onTap: p.likesCount > 0
                                        ? () => _showLikesDialog(p)
                                        : null,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.favorite,
                                            size: 16,
                                            color: p.likesCount > 0
                                                ? Colors.red
                                                : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${p.likesCount}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: p.likesCount > 0
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  InkWell(
                                    onTap: () => _showCommentsDialog(p),
                                    child: Tooltip(
                                      message: p.status != 'approved'
                                          ? 'Post must be approved to add comments'
                                          : 'View & manage comments',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.comment,
                                              size: 16,
                                              color: p.commentsCount > 0
                                                  ? Colors.blue
                                                  : Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${p.commentsCount}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: p.commentsCount > 0
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _showPostDialog(post: p),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete',
                                        onPressed: () => deletePost(p),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ] else ...[
              if (loadingMentioned)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (errorMentioned != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(errorMentioned!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: loadMentionedPosts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Mentioned tab toolbar: search + show hidden
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mentionedSearchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search mentioned posts...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _mentionedQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _mentionedSearchCtrl.clear();
                                      setState(() => _mentionedQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _mentionedQuery = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_hiddenPostIds.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() => _showHidden = !_showHidden),
                          icon: Icon(
                            _showHidden ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                          ),
                          label: Text(_showHidden ? 'Hide hidden' : 'Show hidden (${_hiddenPostIds.length})'),
                        ),
                    ],
                  ),
                ),
                // Mentioned posts table or empty state
                Builder(
                  builder: (ctx) {
                    final visiblePosts = mentionedPosts.where((p) {
                      if (!_showHidden && _hiddenPostIds.contains(p.id)) return false;
                      if (_mentionedQuery.isNotEmpty && !p.content.toLowerCase().contains(_mentionedQuery)) return false;
                      return true;
                    }).toList();
                    if (visiblePosts.isEmpty) {
                      return Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _mentionedQuery.isNotEmpty ? Icons.search_off : Icons.alternate_email,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _mentionedQuery.isNotEmpty
                                    ? 'No matching posts found.'
                                    : _showHidden
                                        ? 'No hidden posts.'
                                        : 'No mentioned posts yet.',
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              if (!_mentionedQuery.isNotEmpty && !_showHidden) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'When someone tags you in a post, it will appear here.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    return Expanded(
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color.fromARGB(186, 234, 143, 143).withValues(alpha: 0.3),
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text('Content', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  DataColumn(
                                    label: Text('Likes', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  DataColumn(
                                    label: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  DataColumn(
                                    label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  DataColumn(
                                    label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                rows: visiblePosts.map((p) {
                                  final preview = p.content.length > 80
                                      ? '${p.content.substring(0, 80)}…'
                                      : p.content;
                                  final isHidden = _hiddenPostIds.contains(p.id);
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: 300,
                                          child: Opacity(
                                            opacity: isHidden ? 0.4 : 1.0,
                                            child: buildHighlightedText(preview, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.favorite,
                                                size: 16,
                                                color: p.likesCount > 0 ? Colors.red : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.likesCount}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: p.likesCount > 0 ? Colors.red : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.comment,
                                                size: 16,
                                                color: p.commentsCount > 0 ? Colors.blue : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.commentsCount}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: p.commentsCount > 0 ? Colors.blue : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}',
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.reply, color: Colors.green),
                                              tooltip: 'Reply',
                                              onPressed: () => _showCommentsDialog(p),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isHidden ? Icons.visibility : Icons.visibility_off,
                                                color: isHidden ? Colors.orange : Colors.grey,
                                              ),
                                              tooltip: isHidden ? 'Unhide' : 'Hide',
                                              onPressed: () {
                                                setState(() {
                                                  if (isHidden) {
                                                    _hiddenPostIds.remove(p.id);
                                                  } else {
                                                    _hiddenPostIds.add(p.id);
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
