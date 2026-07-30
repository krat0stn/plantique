import 'package:flutter/material.dart';
import 'package:pfe_dash/pages/users_page.dart';
import 'package:pfe_dash/pages/Plantspage.dart';
import 'package:pfe_dash/pages/Postspage.dart';
import 'package:pfe_dash/pages/Blogspage.dart';
import 'package:pfe_dash/pages/D3PlantsPage.dart';
import 'package:pfe_dash/pages/ReviewsPage.dart';
import 'package:pfe_dash/pages/DashboardPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarExpanded = true;
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(), // 0
    const UsersPage(), // 1
    const PlantsPage(), // 2
    const PostsPage(), // 3
    const BlogsPage(), // 4
    const D3PlantsPage(), // 5
    const ReviewsPage(), // 6
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
                  Image.asset('assets/images/3d.png', width: 24),
                  '3D Plants',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  6,
                  Image.asset('assets/images/review.png', width: 24),
                  'Reviews',
                  _isSidebarExpanded,
                ),

                const Spacer(),

                // FIX: Logout is NOT a page
                _buildMenuItem(
                  7,
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
        // FIX: Handle logout separately
        if (index == 7) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Logging out...')));

          // TODO:
          // Navigator.pushReplacement(...)
          // FirebaseAuth.instance.signOut();
          return;
        }

        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }
}
