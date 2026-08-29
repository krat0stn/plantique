import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─── MODEL ──────────────────────────────────────────────
class BlogModel {
  final String id;
  final String title;
  final String content;
  final String image;
  final String author;
  final String status;
  final DateTime date;

  BlogModel({
    this.id = '',
    required this.title,
    required this.content,
    required this.image,
    required this.author,
    required this.status,
    required this.date,
  });

  factory BlogModel.fromJson(Map<String, dynamic> json) {
    final authorData = json['author'];
    String authorName = 'Unknown';
    if (authorData is Map) {
      authorName = authorData['username']?.toString() ?? 'Unknown';
    } else if (authorData is String) {
      authorName = authorData;
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return BlogModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      image: json['imageUrl']?.toString() ?? '',
      author: authorName,
      status: json['status']?.toString() ?? 'approved',
      date: parsedDate,
    );
  }
}

// ─── PAGE ───────────────────────────────────────────────
class BlogsPage extends StatefulWidget {
  const BlogsPage({super.key});

  @override
  State<BlogsPage> createState() => _BlogsPageState();
}

class _BlogsPageState extends State<BlogsPage> {
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color editColor = Color(0xFFF59E0B);
  static const Color deleteColor = Color(0xFFEF4444);

  List<BlogModel> blogs = [];
  List<BlogModel> filteredBlogs = [];
  bool loading = true;
  String? error;

  final TextEditingController searchController = TextEditingController();
  String selectedType = "All";

  // Same statuses as posts: pending, approved, declined
  final List<String> blogTypes = ["All", "pending", "approved", "declined"];

  @override
  void initState() {
    super.initState();
    loadBlogs();
  }

  // ── LOAD BLOGS ──────────────────────────────────────────
  Future<void> loadBlogs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.get('/admin/blogs?limit=100');
      final List<dynamic> blogList = data is List ? data : data['data'] ?? [];

      blogs = blogList.map((b) => BlogModel.fromJson(b)).toList();
      filterBlogs();
    } catch (e) {
      setState(() => error = 'Failed to load blogs: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void filterBlogs() {
    setState(() {
      filteredBlogs = blogs.where((blog) {
        final search = searchController.text.toLowerCase();
        final matchesSearch =
            blog.title.toLowerCase().contains(search) ||
            blog.content.toLowerCase().contains(search) ||
            blog.author.toLowerCase().contains(search) ||
            blog.status.toLowerCase().contains(search);

        final matchesType =
            selectedType == "All" || blog.status == selectedType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  // ── APPROVE BLOG ────────────────────────────────────────
  Future<void> approveBlog(String id) async {
    try {
      await ApiService.put('/admin/blogs/$id/approve', {});
      await loadBlogs();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Blog approved")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to approve: $e")));
    }
  }

  // ── DECLINE BLOG ────────────────────────────────────────
  Future<void> declineBlog(String id) async {
    try {
      await ApiService.put('/admin/blogs/$id/decline', {});
      await loadBlogs();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Blog declined")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to decline: $e")));
    }
  }

  // ── EDIT DECISION (fix a mistaken approve/decline) ──────
  void showEditDecisionDialog(BlogModel blog) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit decision"),
          content: Text(
            "This blog is currently \"${blog.status}\". Choose a new status:",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            if (blog.status != "declined")
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  declineBlog(blog.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Decline"),
              ),
            if (blog.status != "approved")
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  approveBlog(blog.id);
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

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteBlog(BlogModel blog) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Blog'),
        content: Text('Are you sure you want to delete "${blog.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: deleteColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.delete('/admin/blogs/${blog.id}');
      setState(() {
        blogs.removeWhere((b) => b.id == blog.id);
        filterBlogs();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${blog.title}" deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  // ── TOKEN HELPER (reads same place as ApiService) ───────
  Future<String?> _getToken() async {
    return ApiService.token;
  }

  // ── CREATE / UPDATE (multipart for image upload) ───────
  Future<void> _submitBlog({
    String? id,
    required String title,
    required String content,
    required PlatformFile? imageFile,
  }) async {
    setState(() => loading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated. Please log in again.'),
          ),
        );
        return;
      }

      final uri = Uri.parse(
        '${ApiService.baseUrl}/admin/blogs${id != null ? '/$id' : ''}',
      );

      final request = http.MultipartRequest(id == null ? 'POST' : 'PUT', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = title.trim();
      request.fields['content'] = content.trim();

      if (imageFile != null && imageFile.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageFile.bytes!,
            filename: imageFile.name,
          ),
        );
      } else if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image is required for new blogs')),
        );
        return;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(id == null ? 'Blog created' : 'Blog updated')),
        );
        await loadBlogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['errormessage'] ?? 'Request failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  // ── ADD / EDIT CONTENT DIALOG ───────────────────────────
  void openBlogForm({BlogModel? existing}) {
    final titleController = TextEditingController(text: existing?.title);
    final contentController = TextEditingController(text: existing?.content);
    PlatformFile? selectedImage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? "Add Blog" : "Edit Blog"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: "Title"),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: contentController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: "Content"),
                      ),
                      const SizedBox(height: 15),

                      // Image picker
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.image,
                                    withData: true,
                                  );
                              if (result != null &&
                                  result.files.single.bytes != null) {
                                setDialogState(() {
                                  selectedImage = result.files.single;
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.image,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "Pick Image",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedImage?.name ??
                                  (existing != null
                                      ? "Keep existing image"
                                      : "No image selected *"),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            selectedImage != null &&
                                selectedImage!.bytes != null
                            ? Image.memory(
                                selectedImage!.bytes!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : existing != null && existing.image.isNotEmpty
                            ? Image.network(
                                existing.image,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Center(child: Text("No preview")),
                              ),
                      ),

                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Author: ${existing?.author ?? 'Will be set automatically'}",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    if (titleController.text.isEmpty ||
                        contentController.text.isEmpty) {
                      return;
                    }
                    if (existing == null && selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select an image")),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    _submitBlog(
                      id: existing?.id,
                      title: titleController.text,
                      content: contentController.text,
                      imageFile: selectedImage,
                    );
                  },
                  child: Text(
                    existing == null ? "Add" : "Save",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void previewImage(BlogModel blog) {
    if (blog.image.isEmpty) return;
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
                  blog.image,
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

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Blogs",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: loading ? null : () => openBlogForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => filterBlogs(),
                    decoration: InputDecoration(
                      hintText: "Search blogs...",
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
                    items: blogTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                        filterBlogs();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: loadBlogs,
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
                        onPressed: loadBlogs,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredBlogs.isEmpty)
              const Expanded(child: Center(child: Text("No blogs found")))
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
                          DataColumn(label: Text("Title")),
                          DataColumn(label: Text("Content")),
                          DataColumn(label: Text("Author")),
                          DataColumn(label: Text("Status")),
                          DataColumn(label: Text("Date")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: filteredBlogs.map((blog) {
                          return DataRow(
                            cells: [
                              DataCell(
                                blog.image.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () => previewImage(blog),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            blog.image,
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
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    blog.title,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    blog.content,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(Text(blog.author)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBackground(blog.status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    blog.status,
                                    style: TextStyle(
                                      color: _statusColor(blog.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(_formatDate(blog.date))),
                              DataCell(
                                Row(
                                  children: [
                                    if (blog.status == "pending") ...[
                                      ElevatedButton.icon(
                                        onPressed: () => approveBlog(blog.id),
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
                                        onPressed: () => declineBlog(blog.id),
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
                                            showEditDecisionDialog(blog),
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
                                      onPressed: () =>
                                          openBlogForm(existing: blog),
                                      icon: const Icon(
                                        Icons.edit_note,
                                        color: editColor,
                                      ),
                                      tooltip: "Edit content",
                                    ),
                                    IconButton(
                                      onPressed: () => deleteBlog(blog),
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
