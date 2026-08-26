import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

/// Shop type choices shown in the dropdown. "Autre" reveals a free-text field.
const List<String> kShopTypeOptions = [
  "Fleuriste",
  "Pépinière",
  "Fournisseur",
  "Autre",
];

/// Generates a random, reasonably strong temporary password.
String generateRandomPassword({int length = 12}) {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*';
  final rand = Random.secure();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

class SupplierModel {
  final String id;
  final String firstName;
  final String lastName;
  final String shopName;
  final String shopType;
  final String email;
  final String phone;
  final String location;
  final String bio;
  final String logoUrl;
  final bool isActive;
  final int productCount;
  final DateTime createdAt;
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;

  SupplierModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.shopName,
    required this.shopType,
    required this.email,
    required this.phone,
    required this.location,
    required this.bio,
    required this.logoUrl,
    required this.isActive,
    required this.productCount,
    required this.createdAt,
    this.subscriptionStart,
    this.subscriptionEnd,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return SupplierModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      shopType: json['shopType']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString() ?? '',
      isActive: json['isActive'] ?? true,
      productCount: (json['productCount'] ?? 0) is int
          ? json['productCount']
          : int.tryParse(json['productCount'].toString()) ?? 0,
      createdAt: parsedDate,
      subscriptionStart: parseOptionalDate(json['subscriptionStart']),
      subscriptionEnd: parseOptionalDate(json['subscriptionEnd']),
    );
  }

  String get ownerName => "$firstName $lastName".trim();
}

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  List<SupplierModel> suppliers = [];
  List<SupplierModel> filteredSuppliers = [];
  bool loading = true;
  String? error;

  final TextEditingController searchController = TextEditingController();
  PlatformFile? selectedLogo;

  // "All" / "Active" / "Suspended"
  String statusFilter = "All";

  @override
  void initState() {
    super.initState();
    loadSuppliers();
  }

  Future<void> loadSuppliers({String q = ''}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final query = q.isNotEmpty ? '?q=${Uri.encodeQueryComponent(q)}' : '';
      final data = await ApiService.get('/suppliers/admin$query');
      final List<dynamic> list = data is List ? data : (data['data'] ?? []);

      suppliers = list.map((s) => SupplierModel.fromJson(s)).toList();
      applyFilter();
    } catch (e) {
      setState(() => error = 'Failed to load suppliers: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void applyFilter() {
    setState(() {
      filteredSuppliers = suppliers.where((s) {
        if (statusFilter == "Active" && !s.isActive) return false;
        if (statusFilter == "Suspended" && s.isActive) return false;
        return true;
      }).toList();
    });
  }

  Widget _datePickerField({
    required BuildContext context,
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
              : 'Select date',
          style: TextStyle(
            color: selectedDate != null ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<void> pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      setState(() => selectedLogo = result.files.first);
    }
  }

  List<http.MultipartFile> _buildFiles() {
    final files = <http.MultipartFile>[];
    if (selectedLogo != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'logo',
          selectedLogo!.bytes!,
          filename: selectedLogo!.name,
        ),
      );
    }
    return files;
  }

  Future<void> addSupplier({
    required String firstName,
    required String lastName,
    required String shopName,
    required String shopType,
    required String email,
    required String password,
    required String phone,
    required String location,
    required String bio,
    String? subscriptionStart,
    String? subscriptionEnd,
  }) async {
    try {
      final fields = {
        'firstName': firstName,
        'lastName': lastName,
        'shopName': shopName,
        'shopType': shopType,
        'email': email,
        'password': password,
        'phone': phone,
        'location': location,
        'bio': bio,
      };
      if (subscriptionStart != null) fields['subscriptionStart'] = subscriptionStart;
      if (subscriptionEnd != null) fields['subscriptionEnd'] = subscriptionEnd;
      await ApiService.multipartRequest('POST', '/suppliers', fields, _buildFiles());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Supplier added")));
      selectedLogo = null;
      await loadSuppliers();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to add supplier: $e")));
    }
  }

  Future<void> editSupplier(
    SupplierModel supplier, {
    required String firstName,
    required String lastName,
    required String shopName,
    required String shopType,
    required String email,
    required String phone,
    required String location,
    required String bio,
    required bool isActive,
    String? subscriptionStart,
    String? subscriptionEnd,
  }) async {
    try {
      final fields = {
        'firstName': firstName,
        'lastName': lastName,
        'shopName': shopName,
        'shopType': shopType,
        'email': email,
        'phone': phone,
        'location': location,
        'bio': bio,
        'isActive': isActive.toString(),
      };
      if (subscriptionStart != null) fields['subscriptionStart'] = subscriptionStart;
      if (subscriptionEnd != null) fields['subscriptionEnd'] = subscriptionEnd;
      await ApiService.multipartRequest('PUT', '/suppliers/${supplier.id}', fields, _buildFiles());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Supplier updated")));
      selectedLogo = null;
      await loadSuppliers();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update supplier: $e")));
    }
  }

  Future<void> toggleActive(SupplierModel supplier) async {
    final activating = !supplier.isActive;
    try {
      await ApiService.multipartRequest('PUT', '/suppliers/${supplier.id}', {
        'isActive': activating.toString(),
      }, []);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activating
                ? "${supplier.shopName} activated"
                : "${supplier.shopName} suspended",
          ),
        ),
      );
      await loadSuppliers();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update status: $e")));
    }
  }

  Future<void> deleteSupplier(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete supplier?"),
        content: Text(
          "Permanently delete \"${supplier.shopName}\"? Their products will be "
          "deactivated. This cannot be undone.",
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
      await ApiService.delete('/suppliers/${supplier.id}');
      setState(() {
        suppliers.removeWhere((s) => s.id == supplier.id);
        applyFilter();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${supplier.shopName} deleted")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  void showAddSupplierDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final shopNameController = TextEditingController();
    final customShopTypeController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(
      text: generateRandomPassword(),
    );
    final phoneController = TextEditingController();
    final locationController = TextEditingController();
    final bioController = TextEditingController();
    selectedLogo = null;
    String? selectedShopType;
    bool obscurePassword = false;
    DateTime? subscriptionStartDate;
    DateTime? subscriptionEndDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("New Supplier"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickLogo();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          selectedLogo == null
                              ? "Pick shop logo (optional)"
                              : "Logo: ${selectedLogo!.name}",
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: shopNameController,
                        decoration: const InputDecoration(
                          labelText: "Shop name *",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedShopType,
                        decoration: const InputDecoration(
                          labelText: "Shop type",
                          border: OutlineInputBorder(),
                        ),
                        items: kShopTypeOptions
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedShopType = value);
                        },
                      ),
                      if (selectedShopType == "Autre") ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customShopTypeController,
                          decoration: const InputDecoration(
                            labelText: "Specify shop type *",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: firstNameController,
                              decoration: const InputDecoration(
                                labelText: "First name *",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: lastNameController,
                              decoration: const InputDecoration(
                                labelText: "Last name *",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password (auto-generated)",
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: obscurePassword ? "Show" : "Hide",
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                              ),
                              IconButton(
                                tooltip: "Copy",
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: passwordController.text,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Password copied"),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: "Regenerate",
                                icon: const Icon(Icons.refresh),
                                onPressed: () => setDialogState(
                                  () => passwordController.text =
                                      generateRandomPassword(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: "Phone",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: "Location",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Bio",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _datePickerField(
                              context: context,
                              label: "Subscription Start",
                              selectedDate: subscriptionStartDate,
                              onPicked: (d) => setDialogState(() => subscriptionStartDate = d),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _datePickerField(
                              context: context,
                              label: "Subscription End",
                              selectedDate: subscriptionEndDate,
                              onPicked: (d) => setDialogState(() => subscriptionEndDate = d),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (shopNameController.text.isEmpty ||
                        firstNameController.text.isEmpty ||
                        lastNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Shop name, first name and last name are required",
                          ),
                        ),
                      );
                      return;
                    }
                    if (selectedShopType == "Autre" &&
                        customShopTypeController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please specify the shop type"),
                        ),
                      );
                      return;
                    }
                    final finalShopType = selectedShopType == "Autre"
                        ? customShopTypeController.text.trim()
                        : (selectedShopType ?? '');
                    Navigator.pop(context);
                    await addSupplier(
                      firstName: firstNameController.text,
                      lastName: lastNameController.text,
                      shopName: shopNameController.text,
                      shopType: finalShopType,
                      email: emailController.text,
                      password: passwordController.text,
                      phone: phoneController.text,
                      location: locationController.text,
                      bio: bioController.text,
                      subscriptionStart: subscriptionStartDate?.toIso8601String(),
                      subscriptionEnd: subscriptionEndDate?.toIso8601String(),
                    );
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showEditSupplierDialog(SupplierModel supplier) {
    final firstNameController = TextEditingController(text: supplier.firstName);
    final lastNameController = TextEditingController(text: supplier.lastName);
    final shopNameController = TextEditingController(text: supplier.shopName);
    final shopTypeController = TextEditingController(text: supplier.shopType);
    final emailController = TextEditingController(text: supplier.email);
    final phoneController = TextEditingController(text: supplier.phone);
    final locationController = TextEditingController(text: supplier.location);
    final bioController = TextEditingController(text: supplier.bio);
    bool isActive = supplier.isActive;
    DateTime? subscriptionStartDate = supplier.subscriptionStart;
    DateTime? subscriptionEndDate = supplier.subscriptionEnd;
    selectedLogo = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit ${supplier.shopName}"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickLogo();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          selectedLogo == null
                              ? "Replace logo (optional)"
                              : "Logo: ${selectedLogo!.name}",
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: shopNameController,
                        decoration: const InputDecoration(
                          labelText: "Shop name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: shopTypeController,
                        decoration: const InputDecoration(
                          labelText: "Shop type",
                          hintText: "e.g. Retail, Wholesale, Dropshipping",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: firstNameController,
                              decoration: const InputDecoration(
                                labelText: "First name",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: lastNameController,
                              decoration: const InputDecoration(
                                labelText: "Last name",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: "Phone",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: "Location",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Bio",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _datePickerField(
                              context: context,
                              label: "Subscription Start",
                              selectedDate: subscriptionStartDate,
                              onPicked: (d) => setDialogState(() => subscriptionStartDate = d),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _datePickerField(
                              context: context,
                              label: "Subscription End",
                              selectedDate: subscriptionEndDate,
                              onPicked: (d) => setDialogState(() => subscriptionEndDate = d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Shop active"),
                        subtitle: Text(
                          isActive
                              ? "Visible on the platform"
                              : "Suspended — hidden from users",
                        ),
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (shopNameController.text.isEmpty) return;
                    Navigator.pop(context);
                    await editSupplier(
                      supplier,
                      firstName: firstNameController.text,
                      lastName: lastNameController.text,
                      shopName: shopNameController.text,
                      shopType: shopTypeController.text,
                      email: emailController.text,
                      phone: phoneController.text,
                      location: locationController.text,
                      bio: bioController.text,
                      isActive: isActive,
                      subscriptionStart: subscriptionStartDate?.toIso8601String(),
                      subscriptionEnd: subscriptionEndDate?.toIso8601String(),
                    );
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
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
            const Text(
              "Suppliers",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (v) => loadSuppliers(q: v),
                    decoration: InputDecoration(
                      hintText: "Search by shop name, owner or email",
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
                ElevatedButton(
                  onPressed: () => loadSuppliers(q: searchController.text),
                  child: const Text("Search"),
                ),
                const SizedBox(width: 15),
                DropdownButton<String>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All")),
                    DropdownMenuItem(value: "Active", child: Text("Active")),
                    DropdownMenuItem(
                      value: "Suspended",
                      child: Text("Suspended"),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => statusFilter = v);
                    applyFilter();
                  },
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () => loadSuppliers(q: searchController.text),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: showAddSupplierDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("New Supplier"),
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
                        onPressed: () => loadSuppliers(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredSuppliers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "No suppliers yet",
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
                        dataRowMaxHeight: 90,
                        columnSpacing: 28,
                        horizontalMargin: 20,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        columns: const [
                          DataColumn(label: Text("Logo")),
                          DataColumn(label: Text("Shop")),
                          DataColumn(label: Text("Type")),
                          DataColumn(label: Text("Owner")),
                          DataColumn(label: Text("Contact")),
                          DataColumn(label: Text("Location")),
                          DataColumn(label: Text("Products")),
                          DataColumn(label: Text("Subscription")),
                          DataColumn(label: Text("Status")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: filteredSuppliers.map((supplier) {
                          return DataRow(
                            cells: [
                              DataCell(
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.green.shade50,
                                  backgroundImage: supplier.logoUrl.isNotEmpty
                                      ? NetworkImage(supplier.logoUrl)
                                      : null,
                                  child: supplier.logoUrl.isEmpty
                                      ? const Icon(
                                          Icons.storefront,
                                          color: Colors.green,
                                        )
                                      : null,
                                ),
                              ),
                              DataCell(
                                Text(
                                  supplier.shopName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    supplier.shopType.isNotEmpty
                                        ? supplier.shopType
                                        : "—",
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(supplier.ownerName)),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (supplier.email.isNotEmpty)
                                      Text(
                                        supplier.email,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    if (supplier.phone.isNotEmpty)
                                      Text(
                                        supplier.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(Text(supplier.location)),
                              DataCell(Text(supplier.productCount.toString())),
                              DataCell(
                                Builder(
                                  builder: (_) {
                                    final end = supplier.subscriptionEnd;
                                    if (end == null) {
                                      return const Text('—', style: TextStyle(color: Colors.grey));
                                    }
                                    final now = DateTime.now();
                                    final expired = now.isAfter(end);
                                    final daysLeft = end.difference(now).inDays;
                                    final dateStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
                                    final color = expired ? Colors.red : (daysLeft <= 30 ? Colors.orange : Colors.green);
                                    final label = expired ? 'Expired ($dateStr)' : '$daysLeft days left';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: supplier.isActive
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    supplier.isActive ? "Active" : "Suspended",
                                    style: TextStyle(
                                      color: supplier.isActive
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          showEditSupplierDialog(supplier),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text("Edit"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => toggleActive(supplier),
                                      icon: Icon(
                                        supplier.isActive
                                            ? Icons.block
                                            : Icons.check_circle,
                                        size: 16,
                                      ),
                                      label: Text(
                                        supplier.isActive
                                            ? "Suspend"
                                            : "Activate",
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: supplier.isActive
                                            ? Colors.grey.shade700
                                            : Colors.teal,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => deleteSupplier(supplier),
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text("Delete"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
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
          ],
        ),
      ),
    );
  }
}
