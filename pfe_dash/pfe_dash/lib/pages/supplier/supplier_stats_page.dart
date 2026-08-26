import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

class MonthlyStat {
  final int month; // 1..12
  final int purchases;
  final double income;

  MonthlyStat({
    required this.month,
    required this.purchases,
    required this.income,
  });

  factory MonthlyStat.fromJson(Map<String, dynamic> json) {
    return MonthlyStat(
      month: (json['month'] is int)
          ? json['month']
          : int.tryParse(json['month'].toString()) ?? 1,
      purchases: (json['purchases'] is int)
          ? json['purchases']
          : int.tryParse(json['purchases'].toString()) ?? 0,
      income: (json['income'] is num)
          ? (json['income'] as num).toDouble()
          : double.tryParse(json['income'].toString()) ?? 0.0,
    );
  }
}

class MostSoldProduct {
  final String name;
  final int quantity;
  final double revenue;

  MostSoldProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  factory MostSoldProduct.fromJson(Map<String, dynamic> json) {
    return MostSoldProduct(
      name: json['name']?.toString() ?? 'Unknown',
      quantity: (json['quantity'] is int)
          ? json['quantity']
          : int.tryParse(json['quantity'].toString()) ?? 0,
      revenue: (json['revenue'] is num)
          ? (json['revenue'] as num).toDouble()
          : double.tryParse(json['revenue'].toString()) ?? 0.0,
    );
  }
}

class SupplierStatsPage extends StatefulWidget {
  const SupplierStatsPage({super.key});

  @override
  State<SupplierStatsPage> createState() => _SupplierStatsPageState();
}

class _SupplierStatsPageState extends State<SupplierStatsPage> {
  bool loading = true;
  String? error;

  int totalProducts = 0;
  int totalPurchases = 0;
  double totalIncome = 0;
  MostSoldProduct? mostSoldProduct;
  int selectedYear = DateTime.now().year;
  List<int> availableYears = [DateTime.now().year];
  List<MonthlyStat> monthlyStats = [];

  static const List<String> _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats({int? year}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final y = year ?? selectedYear;
      final data = await ApiService.get('/supplier-dashboard/stats?year=$y');
      final Map<String, dynamic> stats = data['data'] ?? {};

      final List<dynamic> monthlyList = stats['monthlyStats'] ?? [];
      final List<dynamic> yearsList = stats['availableYears'] ?? [y];

      setState(() {
        totalProducts = stats['totalProducts'] ?? 0;
        totalPurchases = stats['totalPurchases'] ?? 0;
        totalIncome = (stats['totalIncome'] is num)
            ? (stats['totalIncome'] as num).toDouble()
            : double.tryParse(stats['totalIncome'].toString()) ?? 0.0;
        mostSoldProduct = stats['mostSoldProduct'] != null
            ? MostSoldProduct.fromJson(stats['mostSoldProduct'])
            : null;
        selectedYear = stats['year'] ?? y;
        availableYears = yearsList
            .map((e) => int.tryParse(e.toString()) ?? y)
            .toList();
        monthlyStats = monthlyList.map((m) => MonthlyStat.fromJson(m)).toList();
      });
    } catch (e) {
      setState(() => error = 'Failed to load stats: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthlyChart() {
    final maxIncome = monthlyStats.fold<double>(
      0,
      (max, m) => m.income > max ? m.income : max,
    );

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Income by month — $selectedYear',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<int>(
                  value: selectedYear,
                  items: availableYears
                      .map(
                        (y) => DropdownMenuItem(
                          value: y,
                          child: Text(y.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (y) {
                    if (y != null) loadStats(year: y);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (maxIncome == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No sales recorded for this year yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: monthlyStats.map((m) {
                    final barHeight = maxIncome == 0
                        ? 0.0
                        : (m.income / maxIncome) * 170.0;
                    final isBest = m.income == maxIncome && maxIncome > 0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              m.income > 0 ? m.income.toStringAsFixed(0) : '',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isBest
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isBest
                                    ? Colors.green.shade800
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: barHeight < 4 && m.income > 0
                                  ? 4
                                  : barHeight,
                              decoration: BoxDecoration(
                                color: isBest
                                    ? Colors.green.shade600
                                    : const Color.fromARGB(186, 234, 143, 143),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _monthLabels[m.month - 1],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
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
                const Text(
                  'Stats',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => loadStats(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
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
                        onPressed: () => loadStats(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statCard(
                            'Total Products',
                            totalProducts.toString(),
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            'Total Income',
                            '\$${totalIncome.toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            'Total Purchases',
                            totalPurchases.toString(),
                            Icons.shopping_cart,
                            Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            'Best Seller',
                            mostSoldProduct != null
                                ? '${mostSoldProduct!.name}\n(${mostSoldProduct!.quantity} sold)'
                                : 'No sales yet',
                            Icons.star,
                            Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _monthlyChart(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
