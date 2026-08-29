import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pfe_dash/services/api_service.dart';

class SupplierPurchaseModel {
  final String id;
  final String article;
  final int qte;
  final String userInfo;
  final double price;
  final DateTime date;
  final String? receiptNumber;

  SupplierPurchaseModel({
    required this.id,
    required this.article,
    required this.qte,
    required this.userInfo,
    required this.price,
    required this.date,
    this.receiptNumber,
  });

  factory SupplierPurchaseModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(
        (json['date'] ?? json['createdAt'])?.toString() ?? '',
      );
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
      id: json['_id']?.toString() ?? '',
      article: json['article']?.toString() ?? '',
      qte: (json['qte'] is int)
          ? json['qte']
          : int.tryParse(json['qte'].toString()) ?? 0,
      userInfo: resolvedUserInfo,
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price'].toString()) ?? 0.0,
      date: parsedDate,
      receiptNumber: json['receiptNumber']?.toString(),
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

  Future<void> _downloadReceipt(
    String purchaseId,
    String? receiptNumber,
  ) async {
    try {
      final url = Uri.parse(
        '${ApiService.baseUrl}/supplier-dashboard/purchases/$purchaseId/receipt',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${ApiService.token}'},
      );

      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'application/pdf');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: blobUrl)
          ..setAttribute(
            'download',
            'receipt-${receiptNumber ?? purchaseId}.pdf',
          )
          ..click();
        html.Url.revokeObjectUrl(blobUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download receipt')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loadPurchases();
  }

  Future<void> loadPurchases() async {
    setState(() {
      loading = true;
      error = null;
    });
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
                  'Purchases',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: loadPurchases,
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
                        onPressed: loadPurchases,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (purchases.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No purchases yet.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Purchases will appear here when users order your products.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color.fromARGB(
                              186,
                              234,
                              143,
                              143,
                            ).withValues(alpha: 0.3),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Receipt #',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Article',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Qty',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'User Info',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Price',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Receipt',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: purchases.map((p) {
                            final dateStr =
                                '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    p.receiptNumber ?? '—',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: p.receiptNumber != null
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    p.article,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DataCell(Text(p.qte.toString())),
                                DataCell(
                                  SizedBox(width: 200, child: Text(p.userInfo)),
                                ),
                                DataCell(Text(dateStr)),
                                DataCell(
                                  Text(
                                    'dt ${p.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.download,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Download Receipt',
                                    onPressed: () =>
                                        _downloadReceipt(p.id, p.receiptNumber),
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
              ),
          ],
        ),
      ),
    );
  }
}
