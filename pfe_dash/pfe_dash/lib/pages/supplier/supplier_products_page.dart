import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class SupplierProductModel {
  final String id;
  final String name;
  final String category;
  final double price;
  final int quantity;
  final String description;
  final bool inStock;
  final String imageUrl;
  final DateTime createdAt;

  SupplierProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.description,
    required this.inStock,
    required this.imageUrl,
    required this.createdAt,
  });

  factory SupplierProductModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SupplierProductModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price'].toString()) ?? 0.0,
      quantity: (json['quantity'] is int)
          ? json['quantity']
          : int.tryParse(json['quantity'].toString()) ?? 0,
      description: json['description']?.toString() ?? '',
      inStock: json['inStock'] ?? true,
      imageUrl: json['imageUrl']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }
}

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage> {
  List<SupplierProductModel> products = [];
  bool loading = true;
  String? error;
  PlatformFile? selectedImage;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await ApiService.get('/supplier-dashboard/products');
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        products = list.map((p) => SupplierProductModel.fromJson(p)).toList();
      });
    } catch (e) {
      setState(() => error = 'Failed to load products: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) setState(() => selectedImage = result.files.first);
  }

  List<http.MultipartFile> _buildFiles() {
    if (selectedImage == null) return [];
    return [
      http.MultipartFile.fromBytes('image', selectedImage!.bytes!, filename: selectedImage!.name)
    ];
  }

  Future<void> createProduct({
    required String name,
    required String category,
    required String price,
    required String quantity,
    required String description,
    required bool inStock,
  }) async {
    try {
      await ApiService.multipartRequest('POST', '/supplier-dashboard/products', {
        'name': name,
        'category': category,
        'price': price,
        'quantity': quantity,
        'description': description,
        'inStock': inStock.toString(),
      }, _buildFiles());
      selectedImage = null;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product created')));
      await loadProducts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> updateProduct(
    String productId, {
    required String name,
    required String category,
    required String price,
    required String quantity,
    required String description,
    required bool inStock,
  }) async {
    try {
      await ApiService.multipartRequest('PUT', '/supplier-dashboard/products/$productId', {
        'name': name,
        'category': category,
        'price': price,
        'quantity': quantity,
        'description': description,
        'inStock': inStock.toString(),
      }, _buildFiles());
      selectedImage = null;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
      await loadProducts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> importProducts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    try {
      final fileBytes = http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      );
      final response = await ApiService.multipartRequest(
        'POST',
        '/supplier-dashboard/products/import',
        {},
        [fileBytes],
      );
      final imported = response['data']?['imported'] ?? 0;
      final errors = response['data']?['errors'] ?? [];
      if (mounted) {
        String msg = '$imported product(s) imported.';
        if (errors.isNotEmpty) {
          msg += ' ${errors.length} row(s) had errors.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      await loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> deleteProduct(SupplierProductModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.delete('/supplier-dashboard/products/${p.id}');
      setState(() => products.removeWhere((x) => x.id == p.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${p.name}" deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showProductDialog({SupplierProductModel? product}) {
    final nameCtrl        = TextEditingController(text: product?.name ?? '');
    final categoryCtrl    = TextEditingController(text: product?.category ?? '');
    final priceCtrl       = TextEditingController(text: product?.price.toString() ?? '');
    final quantityCtrl    = TextEditingController(text: product?.quantity.toString() ?? '0');
    final descriptionCtrl = TextEditingController(text: product?.description ?? '');
    bool inStock = product?.inStock ?? true;
    selectedImage = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(product == null ? 'New Product' : 'Edit Product'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await pickImage();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.image),
                    label: Text(selectedImage == null
                        ? 'Pick image (optional)'
                        : 'Image: ${selectedImage!.name}'),
                  ),
                  const SizedBox(height: 14),
                  _field(nameCtrl, 'Product name *'),
                  const SizedBox(height: 12),
                  _field(categoryCtrl, 'Type / Category *'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(priceCtrl, 'Price *', keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(quantityCtrl, 'Quantity', keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  _field(descriptionCtrl, 'Description', maxLines: 3),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In Stock'),
                    value: inStock,
                    onChanged: (v) => setDialogState(() => inStock = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || categoryCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and category are required')));
                  return;
                }
                Navigator.pop(ctx);
                if (product == null) {
                  await createProduct(
                    name: nameCtrl.text.trim(),
                    category: categoryCtrl.text.trim(),
                    price: priceCtrl.text.trim(),
                    quantity: quantityCtrl.text.trim(),
                    description: descriptionCtrl.text.trim(),
                    inStock: inStock,
                  );
                } else {
                  await updateProduct(
                    product.id,
                    name: nameCtrl.text.trim(),
                    category: categoryCtrl.text.trim(),
                    price: priceCtrl.text.trim(),
                    quantity: quantityCtrl.text.trim(),
                    description: descriptionCtrl.text.trim(),
                    inStock: inStock,
                  );
                }
              },
              child: Text(product == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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
                const Text('Products', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => loadProducts(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: importProducts,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import CSV/Excel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showProductDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Product'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: loadProducts, child: const Text('Retry')),
                ],
              )))
            else if (products.isEmpty)
              const Expanded(child: Center(
                child: Text('No products yet. Click "New Product" to add one.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color.fromARGB(186, 234, 143, 143).withValues(alpha: 0.3)),
                        columns: const [
                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: products.map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(p.category)),
                            DataCell(Text('\$${p.price.toStringAsFixed(2)}')),
                            DataCell(Text(p.quantity.toString())),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: p.inStock ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.inStock ? 'In Stock' : 'Out',
                                style: TextStyle(
                                  color: p.inStock ? Colors.green.shade800 : Colors.red.shade800,
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            )),
                            DataCell(Row(children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit',
                                onPressed: () => _showProductDialog(product: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => deleteProduct(p),
                              ),
                            ])),
                          ]);
                        }).toList(),
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
