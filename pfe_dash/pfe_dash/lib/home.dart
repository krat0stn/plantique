import 'package:flutter/material.dart';
import 'package:pfe_dash/pages/users_page.dart';
import 'package:pfe_dash/pages/Plantspage.dart';
import 'package:pfe_dash/pages/Postspage.dart';
import 'package:pfe_dash/pages/Blogspage.dart';
import 'package:pfe_dash/pages/ReviewsPage.dart';
import 'package:pfe_dash/pages/DashboardPage.dart';
import 'package:pfe_dash/pages/SuppliersPage.dart';
import 'package:pfe_dash/pages/events_page.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:pfe_dash/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarExpanded = true;
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),  // 0
    const UsersPage(),      // 1
    const PlantsPage(),     // 2
    const PostsPage(),      // 3
    const BlogsPage(),      // 4
    const ReviewsPage(),    // 5
    const SuppliersPage(),  // 6
    const EventsPage(),     // 7
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color.fromARGB(186, 234, 143, 143),
        leading: IconButton(
          icon: Icon(_isSidebarExpanded ? Icons.menu_open : Icons.menu),
          onPressed: () {
            setState(() {
              _isSidebarExpanded = !_isSidebarExpanded;
            });
          },
        ),
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarExpanded ? 250 : 70,
            color: const Color.fromARGB(186, 234, 143, 143),
            child: Column(
              children: [
                const SizedBox(height: 20),

                if (_isSidebarExpanded)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'PLANTIQUE',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(Icons.home, color: Colors.black, size: 30),
                  ),

                _buildMenuItem(
                  0,
                  const Icon(Icons.dashboard, color: Colors.black),
                  'Dashboard',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  1,
                  Image.asset('assets/images/user.png', width: 24),
                  'Users',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  2,
                  const Icon(Icons.local_florist, color: Colors.black),
                  'Plants',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  3,
                  Image.asset('assets/images/post.png', width: 24),
                  'Posts',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  4,
                  Image.asset('assets/images/blog.png', width: 24),
                  'Blogs',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  5,
                  Image.asset('assets/images/review.png', width: 24),
                  'Reviews',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  6,
                  const Icon(Icons.storefront, color: Colors.black),
                  'Suppliers',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  7,
                  const Icon(Icons.event, color: Colors.black),
                  'Events',
                  _isSidebarExpanded,
                ),

                const Spacer(),

                // FIX: Logout is NOT a page
                _buildMenuItem(
                  8,
                  Image.asset('assets/images/logout.png', width: 24),
                  'Logout',
                  _isSidebarExpanded,
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),

              // FIX: Always display the selected page
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, Widget icon, String title, bool isExpanded) {
    final isSelected = _selectedIndex == index;

    return ListTile(
      leading: icon,
      title: isExpanded
          ? Text(
              title,
              style: TextStyle(color: isSelected ? Colors.blue : Colors.black),
            )
          : null,
      selected: isSelected,
      selectedTileColor: Colors.blue.withValues(alpha: 0.1),

      onTap: () {
        // Handle logout separately
        if (index == 8) {
          _logout();
          return;
        }

        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    ApiService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
