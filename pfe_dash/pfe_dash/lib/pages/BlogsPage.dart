import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ─── MODEL ──────────────────────────────────────────────
class BlogModel {
  final String id;
  final String title;
  final String content;
  final String image;
  final String author;
  final DateTime date;

  BlogModel({
    this.id = '',
    required this.title,
    required this.content,
    required this.image,
    required this.author,
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

  @override
  void initState() {
    super.initState();
    loadBlogs();
  }

  // ── LIST ───────────────────────────────────────────────
  Future<void> loadBlogs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final query = searchController.text.trim().isNotEmpty
          ? '?q=${Uri.encodeComponent(searchController.text.trim())}'
          : '';

      // ✅ FIXED: was '/blogs/admin' → now '/admin/blogs'
      final data = await ApiService.get('/admin/blogs$query');
      final List<dynamic> blogList = data['data'] ?? [];

      setState(() {
        blogs = blogList.map((b) => BlogModel.fromJson(b)).toList();
        filteredBlogs = List.from(blogs);
      });
    } catch (e) {
      setState(() => error = 'Failed to load blogs: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void searchBlogs() => loadBlogs();

  // ── DELETE ─────────────────────────────────────────────
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
      // ✅ FIXED: was '/blogs/${blog.id}' → now '/admin/blogs/${blog.id}'
      await ApiService.delete('/admin/blogs/${blog.id}');
      setState(() {
        blogs.removeWhere((b) => b.id == blog.id);
        filteredBlogs.removeWhere((b) => b.id == blog.id);
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

  // ── TOKEN HELPER (reads same place as ApiService) ─────
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

  // ── ADD / EDIT DIALOG ──────────────────────────────────
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

  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
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
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (_) => searchBlogs(),
                    decoration: InputDecoration(
                      hintText: "Search title or content",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: loading ? null : searchBlogs,
                  child: const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          ElevatedButton(
                            onPressed: loadBlogs,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : filteredBlogs.isEmpty
                  ? const Center(child: Text("No blogs found"))
                  : GridView.builder(
                      itemCount: filteredBlogs.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.95,
                          ),
                      itemBuilder: (context, index) {
                        final blog = filteredBlogs[index];
                        return _BlogCard(
                          blog: blog,
                          formattedDate: _formatDate(blog.date),
                          onEdit: () => openBlogForm(existing: blog),
                          onDelete: () => deleteBlog(blog),
                          editColor: editColor,
                          deleteColor: deleteColor,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UI COMPONENTS (unchanged) ──────────────────────────
class _BlogCard extends StatelessWidget {
  final BlogModel blog;
  final String formattedDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color editColor;
  final Color deleteColor;

  const _BlogCard({
    required this.blog,
    required this.formattedDate,
    required this.onEdit,
    required this.onDelete,
    required this.editColor,
    required this.deleteColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  blog.image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            blog.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            blog.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    blog.author,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.edit,
                    color: editColor,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    icon: Icons.delete,
                    color: deleteColor,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
