import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

class ReviewModel {
  final String id;
  final String username;
  final double rating;
  final String comment;
  final DateTime date;

  ReviewModel({
    required this.id,
    required this.username,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final userData = json['user'];
    String username = 'Unknown';
    if (userData is Map) {
      username = userData['username']?.toString() ?? 'Unknown';
    } else if (userData is String) {
      username = userData;
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ReviewModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: username,
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment']?.toString() ?? '',
      date: parsedDate,
    );
  }
}

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  List<ReviewModel> reviews = [];
  bool loading = true;
  String? error;

  int page = 1;
  int limit = 10;
  int total = 0;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  Future<void> loadReviews() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.get(
        '/reviews/admin?page=$page&limit=$limit',
      );
      final List<dynamic> reviewList = data['data'] ?? [];
      final pagination = data['pagination'] ?? {};

      reviews = reviewList.map((r) => ReviewModel.fromJson(r)).toList();
      total = pagination['total'] ?? reviews.length;
      totalPages = pagination['totalPages'] ?? 1;
    } catch (e) {
      setState(() => error = 'Failed to load reviews: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> deleteReview(ReviewModel review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete review?"),
        content: Text(
          "Delete ${review.username}'s review? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.delete('/reviews/admin/${review.id}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Review deleted")));
      // if this was the last item on the page, step back a page
      if (reviews.length == 1 && page > 1) {
        page -= 1;
      }
      await loadReviews();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  void goToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;
    setState(() => page = newPage);
    loadReviews();
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
                  "Reviews",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: loadReviews,
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
                        onPressed: loadReviews,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else if (reviews.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "No reviews yet",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
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
                        dataRowMinHeight: 70,
                        dataRowMaxHeight: 100,
                        columnSpacing: 30,
                        horizontalMargin: 20,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        columns: const [
                          DataColumn(label: Text("User")),
                          DataColumn(label: Text("Rating")),
                          DataColumn(label: Text("Comment")),
                          DataColumn(label: Text("Date")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: reviews.map((review) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  review.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...List.generate(5, (i) {
                                      return Icon(
                                        i < review.rating.round()
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 18,
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${review.rating.toStringAsFixed(1)}/5",
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 400,
                                  child: Text(
                                    review.comment,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${review.date.month}/${review.date.day}/${review.date.year}",
                                ),
                              ),
                              DataCell(
                                ElevatedButton.icon(
                                  onPressed: () => deleteReview(review),
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text("Delete"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
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

            if (!loading && error == null && reviews.isNotEmpty) ...[
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Page $page / $totalPages · $total total"),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: page > 1 ? () => goToPage(page - 1) : null,
                        child: const Text("Prev"),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: page < totalPages
                            ? () => goToPage(page + 1)
                            : null,
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
