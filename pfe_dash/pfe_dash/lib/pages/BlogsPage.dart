import 'package:flutter/material.dart';

class BlogModel {
  final String title;
  final String content;
  final String image;
  final String author;
  final DateTime date;

  BlogModel({
    required this.title,
    required this.content,
    required this.image,
    required this.author,
    required this.date,
  });
}

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

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadBlogs();
  }

  Future<void> loadBlogs() async {
    blogs = [
      BlogModel(
        title: "your plants are dusty and they're struggling...",
        content:
            "I water it, I give it light — why is it still sad? Dusty leaves could be the answer. Cleaning your plants takes 5...",
        image: "https://picsum.photos/seed/leaf/400/500",
        author: "Salma MUSTAPHA",
        date: DateTime(2026, 6, 16),
      ),
      BlogModel(
        title: "The plants that clean your air while you sleep",
        content:
            "Your home holds invisible toxins released by furniture, paint, and cleaning products. These five houseplants...",
        image: "https://picsum.photos/seed/breathe/400/500",
        author: "admin",
        date: DateTime(2026, 6, 16),
      ),
    ];

    filteredBlogs = List.from(blogs);
    setState(() {});
  }

  void searchBlogs() {
    final query = searchController.text.toLowerCase();

    filteredBlogs = blogs.where((blog) {
      return blog.title.toLowerCase().contains(query) ||
          blog.content.toLowerCase().contains(query);
    }).toList();

    setState(() {});
  }

  void deleteBlog(BlogModel blog) {
    setState(() {
      blogs.remove(blog);
      filteredBlogs.remove(blog);
    });
  }

  void openBlogForm({BlogModel? existing}) {
    final titleController = TextEditingController(text: existing?.title);
    final contentController = TextEditingController(text: existing?.content);
    final imageController = TextEditingController(text: existing?.image);
    final authorController = TextEditingController(text: existing?.author);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? "Add Blog" : "Edit Blog"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: "Image URL"),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: authorController,
                    decoration: const InputDecoration(labelText: "Author"),
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
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                if (titleController.text.isEmpty ||
                    contentController.text.isEmpty ||
                    imageController.text.isEmpty ||
                    authorController.text.isEmpty) {
                  return;
                }

                setState(() {
                  if (existing == null) {
                    blogs.add(
                      BlogModel(
                        title: titleController.text,
                        content: contentController.text,
                        image: imageController.text,
                        author: authorController.text,
                        date: DateTime.now(),
                      ),
                    );
                  } else {
                    final index = blogs.indexOf(existing);
                    blogs[index] = BlogModel(
                      title: titleController.text,
                      content: contentController.text,
                      image: imageController.text,
                      author: authorController.text,
                      date: existing.date,
                    );
                  }

                  searchBlogs();
                });

                Navigator.pop(context);
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
                  onPressed: () => openBlogForm(),
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
                  onPressed: searchBlogs,
                  child: const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Expanded(
              child: filteredBlogs.isEmpty
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
