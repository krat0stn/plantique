import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final String picture;
  final String status;
  final int likesCount;
  final int savedCount;
  final int commentsCount;
  final DateTime updatedAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.picture,
    required this.status,
    required this.likesCount,
    required this.savedCount,
    required this.commentsCount,
    required this.updatedAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Handle populated userId (object) or just ID (string)
    final dynamic userData = json['userId'];
    String uid;
    if (userData is Map) {
      uid =
          userData['_id']?.toString() ??
          userData['id']?.toString() ??
          'unknown';
    } else {
      uid = userData?.toString() ?? 'unknown';
    }

    return PostModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: uid,
      content: json['content']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      likesCount: json['likesCount'] ?? 0,
      savedCount: json['savedCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  List<PostModel> posts = [];
  List<PostModel> filteredPosts = [];
  bool loading = true;
  String? error;

  final TextEditingController searchController = TextEditingController();
  String selectedType = "All";

  // Backend uses: pending, approved, declined
  final List<String> postTypes = ["All", "pending", "approved", "declined"];

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  // ── LOAD POSTS ──────────────────────────────────────────────────
  Future<void> loadPosts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.get('/postes/admin/all');
      final List<dynamic> postList = data is List ? data : data['data'] ?? [];

      posts = postList.map((p) => PostModel.fromJson(p)).toList();
      filterPosts();
    } catch (e) {
      setState(() => error = 'Failed to load posts: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ── APPROVE POST ────────────────────────────────────────────────
  Future<void> approvePost(String id) async {
    try {
      await ApiService.put('/postes/$id/approve', {});
      await loadPosts();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Post approved")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to approve: $e")));
    }
  }

  // ── DECLINE POST ────────────────────────────────────────────────
  Future<void> declinePost(String id) async {
    try {
      await ApiService.put('/postes/$id/decline', {});
      await loadPosts();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Post declined")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to decline: $e")));
    }
  }

  // ── RESET POST TO PENDING ──────────────────────────────────────

  // ── EDIT DECISION (fix a mistaken approve/decline) ─────────────
  void showEditDecisionDialog(PostModel post) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit decision"),
          content: Text(
            "This post is currently \"${post.status}\". Choose a new status:",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            if (post.status != "declined")
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  declinePost(post.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Decline"),
              ),
            if (post.status != "approved")
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  approvePost(post.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Approve"),
              ),
          ],
        );
      },
    );
  }

  // ── DELETE POST ─────────────────────────────────────────────────
  Future<void> deletePost(PostModel post) async {
    try {
      await ApiService.delete('/postes/${post.id}');
      setState(() {
        posts.removeWhere((p) => p.id == post.id);
        filterPosts();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Post deleted")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  void filterPosts() {
    setState(() {
      filteredPosts = posts.where((post) {
        final search = searchController.text.toLowerCase();
        final matchesSearch =
            post.status.toLowerCase().contains(search) ||
            post.userId.toLowerCase().contains(search) ||
            post.content.toLowerCase().contains(search);

        final matchesType =
            selectedType == "All" || post.status == selectedType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void previewImage(PostModel post) {
    if (post.picture.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.picture,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, size: 60),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "declined":
        return Colors.red;
      case "pending":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case "approved":
        return Colors.green.shade100;
      case "declined":
        return Colors.red.shade100;
      case "pending":
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
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
            const Text(
              "Posts",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => filterPosts(),
                    decoration: InputDecoration(
                      hintText: "Search posts...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: postTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                        filterPosts();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: loadPosts,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                ),
              ],
            ),
            const SizedBox(height: 25),

            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: loadPosts,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 60,
                        dataRowMinHeight: 80,
                        dataRowMaxHeight: 100,
                        columnSpacing: 30,
                        horizontalMargin: 20,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        columns: const [
                          DataColumn(label: Text("Image")),
                          DataColumn(label: Text("User ID")),
                          DataColumn(label: Text("Content")),
                          DataColumn(label: Text("Status")),
                          DataColumn(label: Text("Likes")),
                          DataColumn(label: Text("Saves")),
                          DataColumn(label: Text("Comments")),
                          DataColumn(label: Text("Updated")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: filteredPosts.map((post) {
                          return DataRow(
                            cells: [
                              DataCell(
                                post.picture.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () => previewImage(post),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            post.picture,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 50,
                                                      height: 50,
                                                      color:
                                                          Colors.grey.shade300,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        size: 20,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                      )
                                    : const CircleAvatar(
                                        radius: 25,
                                        child: Icon(Icons.image_not_supported),
                                      ),
                              ),
                              DataCell(
                                Text(
                                  post.userId.substring(
                                        0,
                                        post.userId.length > 8
                                            ? 8
                                            : post.userId.length,
                                      ) +
                                      '...',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    post.content,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBackground(post.status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    post.status,
                                    style: TextStyle(
                                      color: _statusColor(post.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(post.likesCount.toString())),
                              DataCell(Text(post.savedCount.toString())),
                              DataCell(Text(post.commentsCount.toString())),
                              DataCell(
                                Text(
                                  "${post.updatedAt.day}/${post.updatedAt.month}/${post.updatedAt.year}",
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    if (post.status == "pending") ...[
                                      ElevatedButton.icon(
                                        onPressed: () => approvePost(post.id),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text("Approve"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        onPressed: () => declinePost(post.id),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text("Decline"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ] else ...[
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            showEditDecisionDialog(post),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text("Edit"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueGrey,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    IconButton(
                                      onPressed: () => deletePost(post),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: "Delete",
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
          ],
        ),
      ),
    );
  }
}
