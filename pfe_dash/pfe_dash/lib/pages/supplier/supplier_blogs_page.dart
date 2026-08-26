import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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

class SupplierBlogModel {
  final String id;
  final String title;
  final String content;
  final String excerpt;
  final String imageUrl;
  final String status;
  final DateTime createdAt;

  SupplierBlogModel({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
  });

  factory SupplierBlogModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return SupplierBlogModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: parsedDate,
    );
  }
}

class SupplierBlogsPage extends StatefulWidget {
  const SupplierBlogsPage({super.key});

  @override
  State<SupplierBlogsPage> createState() => _SupplierBlogsPageState();
}

class _SupplierBlogsPageState extends State<SupplierBlogsPage> {
  List<SupplierBlogModel> blogs = [];
  bool loading = true;
  String? error;
  PlatformFile? selectedImage;

  @override
  void initState() {
    super.initState();
    loadBlogs();
  }

  Future<void> loadBlogs() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await ApiService.get('/supplier-dashboard/blogs');
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        blogs = list.map((b) => SupplierBlogModel.fromJson(b)).toList();
      });
    } catch (e) {
      setState(() => error = 'Failed to load blogs: $e');
    } finally {
      setState(() => loading = false);
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
        'image',
        selectedImage!.bytes!,
        filename: selectedImage!.name,
      ),
    ];
  }

  Future<void> createBlog({
    required String title,
    required String content,
    required String excerpt,
  }) async {
    try {
      await ApiService.multipartRequest('POST', '/supplier-dashboard/blogs', {
        'title': title,
        'content': content,
        'excerpt': excerpt,
      }, _buildFiles());
      selectedImage = null;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blog created — pending admin review')),
        );
      await loadBlogs();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> updateBlog(
    String blogId, {
    required String title,
    required String content,
    required String excerpt,
  }) async {
    try {
      await ApiService.multipartRequest(
        'PUT',
        '/supplier-dashboard/blogs/$blogId',
        {'title': title, 'content': content, 'excerpt': excerpt},
        _buildFiles(),
      );
      selectedImage = null;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blog updated — returned to pending review'),
          ),
        );
      await loadBlogs();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> deleteBlog(SupplierBlogModel b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete blog?'),
        content: Text('Delete "${b.title}"? This cannot be undone.'),
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
      await ApiService.delete('/supplier-dashboard/blogs/${b.id}');
      setState(() => blogs.removeWhere((x) => x.id == b.id));
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${b.title}" deleted')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showBlogDialog({SupplierBlogModel? blog}) {
    final titleCtrl = TextEditingController(text: blog?.title ?? '');
    final contentCtrl = TextEditingController(text: blog?.content ?? '');
    final excerptCtrl = TextEditingController(text: blog?.excerpt ?? '');
    selectedImage = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(blog == null ? 'New Blog' : 'Edit Blog'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (blog == null) ...[
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
                              'New blogs require admin approval before they are published.',
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
                          ? 'Attach cover image (optional)'
                          : 'Image: ${selectedImage!.name}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: excerptCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Excerpt (optional)',
                      hintText: 'Short summary shown in listings',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Content *',
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
                if (titleCtrl.text.trim().isEmpty ||
                    contentCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title and content are required'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                if (blog == null) {
                  await createBlog(
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    excerpt: excerptCtrl.text.trim(),
                  );
                } else {
                  await updateBlog(
                    blog.id,
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    excerpt: excerptCtrl.text.trim(),
                  );
                }
              },
              child: Text(blog == null ? 'Publish for Review' : 'Save'),
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
                  'Blogs',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: loadBlogs,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showBlogDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Blog'),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                        onPressed: loadBlogs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (blogs.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No blogs yet. Click "New Blog" to create one.',
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
                              'Title',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Excerpt',
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
                        rows: blogs.map((b) {
                          final excerpt = b.excerpt.isNotEmpty
                              ? (b.excerpt.length > 60
                                    ? '${b.excerpt.substring(0, 60)}…'
                                    : b.excerpt)
                              : (b.content.length > 60
                                    ? '${b.content.substring(0, 60)}…'
                                    : b.content);
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  b.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    excerpt,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                              DataCell(_statusBadge(b.status)),
                              DataCell(
                                Text(
                                  '${b.createdAt.year}-${b.createdAt.month.toString().padLeft(2, '0')}-${b.createdAt.day.toString().padLeft(2, '0')}',
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
                                      onPressed: () => _showBlogDialog(blog: b),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () => deleteBlog(b),
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
