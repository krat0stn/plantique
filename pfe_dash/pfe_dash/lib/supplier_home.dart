// lib/supplier_home.dart
import 'package:flutter/material.dart';
import 'package:pfe_dash/pages/supplier/supplier_products_page.dart';
import 'package:pfe_dash/pages/supplier/supplier_posts_page.dart';
import 'package:pfe_dash/pages/supplier/supplier_blogs_page.dart';
import 'package:pfe_dash/pages/supplier/supplier_purchases_page.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:pfe_dash/main.dart';

class SupplierHomePage extends StatefulWidget {
  const SupplierHomePage({super.key});

  @override
  State<SupplierHomePage> createState() => _SupplierHomePageState();
}

class _SupplierHomePageState extends State<SupplierHomePage> {
  bool _isSidebarExpanded = true;
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const SupplierProductsPage(),   // 0
    const SupplierPostsPage(),      // 1
    const SupplierBlogsPage(),      // 2
    const SupplierPurchasesPage(),  // 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Dashboard'),
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
                      'SUPPLIER',
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
                    child: Icon(Icons.storefront, color: Colors.black, size: 30),
                  ),

                _buildMenuItem(
                  0,
                  const Icon(Icons.inventory_2, color: Colors.black),
                  'Products',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  1,
                  const Icon(Icons.article_outlined, color: Colors.black),
                  'Posts',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  2,
                  const Icon(Icons.book_outlined, color: Colors.black),
                  'Blogs',
                  _isSidebarExpanded,
                ),

                _buildMenuItem(
                  3,
                  const Icon(Icons.shopping_cart_outlined, color: Colors.black),
                  'Purchases',
                  _isSidebarExpanded,
                ),

                const Spacer(),

                _buildMenuItem(
                  4,
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
        if (index == 4) {
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
