import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

class SupplierPurchaseModel {
  final String id;
  final String article;
  final int qte;
  final String userInfo;
  final double price;
  final DateTime date;

  SupplierPurchaseModel({
    required this.id,
    required this.article,
    required this.qte,
    required this.userInfo,
    required this.price,
    required this.date,
  });

  factory SupplierPurchaseModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(
          (json['date'] ?? json['createdAt'])?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    // userInfo may be a String directly, or derived from populated userId
    String resolvedUserInfo = json['userInfo']?.toString() ?? '';
    if (resolvedUserInfo.isEmpty && json['userId'] is Map) {
      final u = json['userId'] as Map;
      resolvedUserInfo = '${u['username'] ?? ''} (${u['email'] ?? ''})';
    }

    return SupplierPurchaseModel(
      id:       json['_id']?.toString() ?? '',
      article:  json['article']?.toString() ?? '',
      qte:      (json['qte'] is int)
                    ? json['qte']
                    : int.tryParse(json['qte'].toString()) ?? 0,
      userInfo: resolvedUserInfo,
      price:    (json['price'] is num)
                    ? (json['price'] as num).toDouble()
                    : double.tryParse(json['price'].toString()) ?? 0.0,
      date:     parsedDate,
    );
  }
}

class SupplierPurchasesPage extends StatefulWidget {
  const SupplierPurchasesPage({super.key});

  @override
  State<SupplierPurchasesPage> createState() => _SupplierPurchasesPageState();
}

class _SupplierPurchasesPageState extends State<SupplierPurchasesPage> {
  List<SupplierPurchaseModel> purchases = [];
  bool loading = true;
  String? error;

  // Summary stats
  int get totalOrders => purchases.length;
  double get totalRevenue => purchases.fold(0.0, (sum, p) => sum + p.price);
  int get totalItems => purchases.fold(0, (sum, p) => sum + p.qte);

  @override
  void initState() {
    super.initState();
    loadPurchases();
  }

  Future<void> loadPurchases() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await ApiService.get('/supplier-dashboard/purchases');
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        purchases = list.map((p) => SupplierPurchaseModel.fromJson(p)).toList();
      });
    } catch (e) {
      setState(() => error = 'Failed to load purchases: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
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
                const Text('Purchases', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Read-only — auto-generated from user orders',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: loadPurchases,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!loading && error == null) ...[
              // Summary stats cards
              Row(
                children: [
                  Expanded(child: _statCard('Total Orders', totalOrders.toString(), Icons.receipt_long, Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Total Revenue', '\$${totalRevenue.toStringAsFixed(2)}', Icons.attach_money, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Items Sold', totalItems.toString(), Icons.inventory, Colors.orange)),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: loadPurchases, child: const Text('Retry')),
                ],
              )))
            else if (purchases.isEmpty)
              const Expanded(child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No purchases yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Text('Purchases will appear here when users order your products.',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ))
            else
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color.fromARGB(186, 234, 143, 143).withValues(alpha: 0.3)),
                          columns: const [
                            DataColumn(label: Text('Article', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('User Info', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: purchases.map((p) {
                            final dateStr =
                              '${p.date.year}-${p.date.month.toString().padLeft(2,'0')}-${p.date.day.toString().padLeft(2,'0')}';
                            return DataRow(cells: [
                              DataCell(Text(p.article, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(p.qte.toString())),
                              DataCell(SizedBox(width: 200, child: Text(p.userInfo))),
                              DataCell(Text(dateStr)),
                              DataCell(Text('\$${p.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green))),
                            ]);
                          }).toList(),
                        ),
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
