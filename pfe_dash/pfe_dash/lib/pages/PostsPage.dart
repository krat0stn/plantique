import 'package:flutter/material.dart';

class PostModel {
  final String user;
  final String content;
  final String image;
  final String status;
  final String likes;
  final String saves;
  final DateTime updated;

  PostModel({
    required this.user,
    required this.content,
    required this.image,
    required this.status,
    required this.likes,
    required this.saves,
    required this.updated,
  });
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  List<PostModel> posts = [];
  List<PostModel> filteredPosts = [];

  final TextEditingController searchController = TextEditingController();

  String selectedType = "All";

  final List<String> postTypes = ["All", "approved", "denied"];

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    posts = [
      PostModel(
        user: "John Doe",
        content: "This is a beautiful rose!",
        image: "https://picsum.photos/200",
        status: "approved",
        likes: "10",
        saves: "5",
        updated: DateTime.now(),
      ),
      PostModel(
        user: "Jane Smith",
        content: "Check out this amazing basil plant!",
        image: "https://picsum.photos/201",
        status: "denied",
        likes: "15",
        saves: "8",
        updated: DateTime.now(),
      ),
      PostModel(
        user: "Alice Johnson",
        content: "Beautiful oak tree!",
        image: "https://picsum.photos/202",
        status: "denied",
        likes: "20",
        saves: "10",
        updated: DateTime.now(),
      ),
      PostModel(
        user: "Bob Wilson",
        content: "Check out this amazing aloe vera!",
        image: "https://picsum.photos/203",
        status: "approved",
        likes: "25",
        saves: "12",
        updated: DateTime.now(),
      ),
    ];

    filteredPosts = List.from(posts);

    setState(() {});
  }

  void filterPosts() {
    filteredPosts = posts.where((post) {
      final matchesSearch =
          post.status.toLowerCase().contains(
            searchController.text.toLowerCase(),
          ) ||
          post.user.toLowerCase().contains(
            searchController.text.toLowerCase(),
          ) ||
          post.content.toLowerCase().contains(
            searchController.text.toLowerCase(),
          );

      final matchesType = selectedType == "All" || post.status == selectedType;

      return matchesSearch && matchesType;
    }).toList();

    setState(() {});
  }

  void previewImage(PostModel post) {
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
                  post.image,
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
      case "denied":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case "approved":
        return Colors.green.shade100;
      case "denied":
        return Colors.red.shade100;
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
                    initialValue: selectedType,
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
            Expanded(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 60,
                    dataRowMinHeight: 80,
                    dataRowMaxHeight: 80,
                    columnSpacing: 35,
                    horizontalMargin: 20,
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    columns: const [
                      DataColumn(label: Text("Image")),
                      DataColumn(label: Text("User")),
                      DataColumn(label: Text("Content")),
                      DataColumn(label: Text("Status")),
                      DataColumn(label: Text("Likes")),
                      DataColumn(label: Text("Saves")),
                      DataColumn(label: Text("Updated")),
                    ],
                    rows: filteredPosts.map((post) {
                      return DataRow(
                        cells: [
                          DataCell(
                            GestureDetector(
                              onTap: () => previewImage(post),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  post.image,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 20,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              post.user,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                post.content,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
                          DataCell(Text(post.likes)),
                          DataCell(Text(post.saves)),
                          DataCell(
                            Text(
                              "${post.updated.day}/${post.updated.month}/${post.updated.year}",
                            ),
                          ),
                        ],
                      );
                    }).toList(),
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
