import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

const _kStatusColors = {
  'pending':  Color(0xFFFFF3CD),
  'approved': Color(0xFFD4EDDA),
  'declined': Color(0xFFF8D7DA),
};
const _kStatusTextColors = {
  'pending':  Color(0xFF856404),
  'approved': Color(0xFF155724),
  'declined': Color(0xFF721C24),
};

class SupplierPostModel {
  final String id;
  final String content;
  final String picture;
  final String status;
  final DateTime createdAt;

  SupplierPostModel({
    required this.id,
    required this.content,
    required this.picture,
    required this.status,
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
      id:        json['_id']?.toString() ?? '',
      content:   json['content']?.toString() ?? '',
      picture:   json['picture']?.toString() ?? '',
      status:    json['status']?.toString() ?? 'pending',
      createdAt: parsedDate,
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
  bool loading = true;
  String? error;
  PlatformFile? selectedImage;

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    setState(() { loading = true; error = null; });
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

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) setState(() => selectedImage = result.files.first);
  }

  List<http.MultipartFile> _buildFiles() {
    if (selectedImage == null) return [];
    return [
      http.MultipartFile.fromBytes('picture', selectedImage!.bytes!, filename: selectedImage!.name)
    ];
  }

  Future<void> createPost({required String content}) async {
    try {
      await ApiService.multipartRequest('POST', '/supplier-dashboard/posts',
          {'content': content}, _buildFiles());
      selectedImage = null;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created — pending admin review')));
      await loadPosts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> updatePost(String postId, {required String content}) async {
    try {
      await ApiService.multipartRequest('PUT', '/supplier-dashboard/posts/$postId',
          {'content': content}, _buildFiles());
      selectedImage = null;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated — returned to pending review')));
      await loadPosts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> deletePost(SupplierPostModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text('Delete this post? This cannot be undone.\n\n"${p.content.substring(0, p.content.length.clamp(0, 80))}..."'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
                      child: const Row(children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'New posts require admin approval before they are published.',
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ElevatedButton.icon(
                    onPressed: () async {
                      await pickImage();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.image),
                    label: Text(selectedImage == null
                        ? 'Attach image (optional)'
                        : 'Image: ${selectedImage!.name}'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 5,
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (contentCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Content is required')));
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
                const Text('Posts', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'New & edited posts require admin approval',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: loadPosts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showPostDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Post'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: loadPosts, child: const Text('Retry')),
                ],
              )))
            else if (posts.isEmpty)
              const Expanded(child: Center(
                child: Text('No posts yet. Click "New Post" to create one.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              ))
            else
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color.fromARGB(186, 234, 143, 143).withValues(alpha: 0.3)),
                        columns: const [
                          DataColumn(label: Text('Content', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: posts.map((p) {
                          final preview = p.content.length > 80
                              ? '${p.content.substring(0, 80)}…'
                              : p.content;
                          return DataRow(cells: [
                            DataCell(
                              SizedBox(width: 300, child: Text(preview)),
                            ),
                            DataCell(_statusBadge(p.status)),
                            DataCell(Text(
                              '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2,'0')}-${p.createdAt.day.toString().padLeft(2,'0')}',
                            )),
                            DataCell(Row(children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit',
                                onPressed: () => _showPostDialog(post: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => deletePost(p),
                              ),
                            ])),
                          ]);
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
