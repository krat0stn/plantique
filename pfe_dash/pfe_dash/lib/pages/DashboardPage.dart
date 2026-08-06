import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;

  // metrics
  int totalUsers = 0;
  int totalBlogs = 0;
  int totalPosts = 0;
  int pendingPosts = 0;
  double avgRating = 0;
  int reviewsCount = 0;

  List<dynamic> latestBlogs = [];
  List<dynamic> latestReviews = [];

  // plants analytics
  List<Map<String, dynamic>> plantTypes = [];
  int totalPlants = 0;
  int totalArModels = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.get('/admin/dashboard/metrics'),
        ApiService.get('/admin/dashboard/plants-analytics'),
      ]);

      final metrics = results[0];
      final analytics = results[1];

      final cards = metrics['cards'] ?? {};
      final latest = metrics['latest'] ?? {};

      totalUsers = cards['totalUsers'] ?? 0;
      totalBlogs = cards['totalBlogs'] ?? 0;
      totalPosts = cards['totalPosts'] ?? 0;
      pendingPosts = cards['pendingPosts'] ?? 0;
      avgRating = (cards['avgRating'] ?? 0).toDouble();
      reviewsCount = cards['reviewsCount'] ?? 0;

      latestBlogs = latest['blogs'] ?? [];
      latestReviews = latest['reviews'] ?? [];

      final aCards = analytics['cards'] ?? {};
      totalPlants = aCards['totalPlants'] ?? 0;
      totalArModels = aCards['totalArModels'] ?? 0;

      final breakdown = analytics['breakdown'] ?? {};
      final typesRaw = breakdown['plantTypes'] as List<dynamic>? ?? [];
      plantTypes = typesRaw
          .map((t) => {'name': t['name'], 'count': t['count']})
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      error = 'Failed to load dashboard: $e';
    } finally {
      setState(() => loading = false);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return '${months}mo ago';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
  }

  DateTime _parseDate(dynamic v) {
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        backgroundColor: const Color(0xfff5f6fa),
        elevation: 0,
        title: const Text('Dashboard'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: loadDashboard,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Summary cards ──────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _CardData(
                            'USERS',
                            totalUsers.toString(),
                            Icons.people,
                            const Color(0xFF16A34A),
                          ),
                          _CardData(
                            'BLOGS',
                            totalBlogs.toString(),
                            Icons.article,
                            const Color(0xFF7C3AED),
                          ),
                          _CardData(
                            'POSTS',
                            totalPosts.toString(),
                            Icons.chat_bubble,
                            const Color(0xFF2563EB),
                          ),
                          _CardData(
                            'REVIEWS',
                            reviewsCount.toString(),
                            Icons.reviews,
                            const Color(0xFF0EA5E9),
                          ),
                          _CardData(
                            'PENDING POSTS',
                            pendingPosts.toString(),
                            Icons.hourglass_bottom,
                            const Color(0xFFF59E0B),
                          ),
                          _CardData(
                            'AVG RATING',
                            avgRating.toStringAsFixed(1),
                            Icons.star,
                            const Color(0xFFEAB308),
                          ),
                          _CardData(
                            '3D MODELS',
                            totalArModels.toString(),
                            Icons.view_in_ar,
                            const Color(0xFFDB2777),
                          ),
                          _CardData(
                            'PLANTS',
                            totalPlants.toString(),
                            Icons.local_florist,
                            const Color(0xFF059669),
                          ),
                        ];

                        final crossAxisCount = constraints.maxWidth > 1100
                            ? 4
                            : constraints.maxWidth > 700
                            ? 3
                            : 2;

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          children: cards
                              .map((c) => _buildStatCard(c))
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Plant Types + Latest Blogs ─────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 800;
                        final plantTypesCard = _buildPanel(
                          title: "Plant Types",
                          height: 300,
                          child: plantTypes.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No plant type data yet",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : _buildPlantTypesChart(),
                        );

                        final blogsCard = _buildPanel(
                          title: "Latest Blogs",
                          height: 300,
                          child: latestBlogs.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No blogs yet",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: latestBlogs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final blog = latestBlogs[index];
                                    final author = blog['author'];
                                    String authorName = 'Unknown';
                                    if (author is Map) {
                                      authorName =
                                          author['username']?.toString() ??
                                          'Unknown';
                                    } else if (author is String) {
                                      authorName = author;
                                    }
                                    final date = _parseDate(blog['createdAt']);
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.indigo.shade100,
                                        child: Text(
                                          authorName.isNotEmpty
                                              ? authorName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.indigo,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        blog['title']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "$authorName · ${_timeAgo(date)}",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              plantTypesCard,
                              const SizedBox(height: 20),
                              blogsCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: plantTypesCard),
                            const SizedBox(width: 20),
                            Expanded(child: blogsCard),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Reviews ─────────────────────────────────
                    _buildPanel(
                      title: "Recent Reviews",
                      height: null,
                      child: latestReviews.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  "No reviews yet",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : Column(
                              children: latestReviews.map((review) {
                                final user = review['user'];
                                String username = 'Unknown';
                                if (user is Map) {
                                  username =
                                      user['username']?.toString() ?? 'Unknown';
                                }
                                final rating = (review['rating'] ?? 0)
                                    .toDouble();
                                final date = _parseDate(review['createdAt']);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.orange.shade100,
                                        child: Text(
                                          username.isNotEmpty
                                              ? username[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  username,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _timeAgo(date),
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              review['comment']?.toString() ??
                                                  '',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${rating.toStringAsFixed(1)}/5",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlantTypesChart() {
    final maxCount = plantTypes
        .map((t) => t['count'] as int)
        .fold<int>(1, (a, b) => a > b ? a : b);

    final colors = [
      const Color(0xFF16A34A),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFEAB308),
      const Color(0xFFDB2777),
      const Color(0xFF0EA5E9),
      const Color(0xFFF59E0B),
      const Color(0xFF059669),
    ];

    return ListView.builder(
      itemCount: plantTypes.length,
      itemBuilder: (context, index) {
        final type = plantTypes[index];
        final name = type['name'].toString();
        final count = type['count'] as int;
        final ratio = count / maxCount;
        final color = colors[index % colors.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 14,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(
                  count.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanel({
    required String title,
    required double? height,
    required Widget child,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          height == null ? child : Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildStatCard(_CardData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: data.color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(data.icon, color: data.color, size: 28),
        ],
      ),
    );
  }
}

class _CardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _CardData(this.title, this.value, this.icon, this.color);
}
