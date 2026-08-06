import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlantModel {
  final String id;
  final String slug;
  final String preview;
  final String plant;
  final String scientific;
  final String tunisianName;
  final String type;
  final String description;

  PlantModel({
    required this.id,
    required this.slug,
    required this.preview,
    required this.plant,
    required this.scientific,
    required this.tunisianName,
    required this.type,
    required this.description,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    return PlantModel(
      id: json['_id'] ?? json['id'] ?? '',
      slug: json['slug'] ?? '',
      preview: json['imageUrl'] ?? '',
      plant: json['plantName'] ?? '',
      scientific: json['scientificName'] ?? '',
      tunisianName: json['tunisianName'] ?? '',
      type: json['plantType'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class PlantsPage extends StatefulWidget {
  const PlantsPage({super.key});

  @override
  State<PlantsPage> createState() => _PlantsPageState();
}

class _PlantsPageState extends State<PlantsPage> {
  List<PlantModel> plants = [];
  List<PlantModel> filteredPlants = [];
  bool loading = true;
  String? error;
  PlatformFile? selectedImage;

  final TextEditingController searchController = TextEditingController();
  String selectedType = "All";
  List<String> availableTypes = ["All"];

  @override
  void initState() {
    super.initState();
    loadTypes();
    loadPlants();
  }

  Future<void> loadTypes() async {
    try {
      final data = await ApiService.get('/plant-care/types');
      final List<dynamic> types = data['data'] ?? [];
      setState(() {
        availableTypes = ["All", ...types.map((t) => t.toString())];
      });
    } catch (e) {
      print('Failed to load types: $e');
    }
  }

  Future<void> loadPlants() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final query = selectedType != "All" ? '?type=$selectedType' : '';
      final data = await ApiService.get('/plant-care$query');
      final List<dynamic> plantList = data['data'] ?? [];

      plants = plantList.map((p) => PlantModel.fromJson(p)).toList();
      filterPlants();
    } catch (e) {
      setState(() => error = 'Failed to load plants: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void filterPlants() {
    setState(() {
      filteredPlants = plants.where((plant) {
        final search = searchController.text.toLowerCase();
        final matchesSearch =
            plant.plant.toLowerCase().contains(search) ||
            plant.scientific.toLowerCase().contains(search) ||
            plant.tunisianName.toLowerCase().contains(search);

        final matchesType =
            selectedType == "All" ||
            plant.type.toLowerCase().contains(selectedType.toLowerCase());

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  // ── ADD PLANT ───────────────────────────────────────────────────
  Future<void> addPlant(Map<String, dynamic> body) async {
    try {
      await ApiService.post('/plant-care', body);
      await loadPlants();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Plant added successfully")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to add plant: $e")));
    }
  }

  // ── EDIT PLANT ──────────────────────────────────────────────────
  Future<void> editPlant(String id, Map<String, dynamic> body) async {
    try {
      await ApiService.put('/plant-care/$id', body);
      await loadPlants();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plant updated successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update plant: $e")));
    }
  }

  // ── DELETE PLANT ────────────────────────────────────────────────
  Future<void> deletePlant(PlantModel plant) async {
    try {
      await ApiService.delete('/plant-care/${plant.id}');
      setState(() {
        plants.removeWhere((p) => p.id == plant.id);
        filterPlants();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${plant.plant} deleted")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() => selectedImage = result.files.first);
    }
  }

  // ── ADD PLANT DIALOG ────────────────────────────────────────────
  void showAddPlantDialog() {
    final plantController = TextEditingController();
    final scientificController = TextEditingController();
    final tunisianController = TextEditingController();
    final descController = TextEditingController();
    String type = availableTypes.length > 1 ? availableTypes[1] : 'Flower';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Plant"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image picker
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickImage();
                          setDialogState(
                            () {},
                          ); // Refresh dialog to show filename
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          selectedImage == null
                              ? "Pick Image"
                              : "Image: ${selectedImage!.name}",
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Plant Name
                      TextField(
                        controller: plantController,
                        decoration: const InputDecoration(
                          labelText: "Plant Name *",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Scientific Name
                      TextField(
                        controller: scientificController,
                        decoration: const InputDecoration(
                          labelText: "Scientific Name *",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tunisian Name
                      TextField(
                        controller: tunisianController,
                        decoration: const InputDecoration(
                          labelText: "Tunisian Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Type dropdown
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(
                          labelText: "Type",
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .where((e) => e != "All")
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => type = value!),
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
                    if (plantController.text.isEmpty ||
                        scientificController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Plant name and Scientific name are required",
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    // Convert image to base64 if selected
                    String? imageBase64;
                    if (selectedImage != null) {
                      imageBase64 = base64Encode(selectedImage!.bytes!);
                    }

                    // Send as normal JSON (not multipart)
                    await addPlant({
                      'plantName': plantController.text,
                      'scientificName': scientificController.text,
                      'tunisianName': tunisianController.text,
                      'description': descController.text,
                      'plantType': type,
                      'slug': plantController.text.toLowerCase().replaceAll(
                        ' ',
                        '-',
                      ),
                      'imageBase64': imageBase64, // ← base64 string or null
                    });

                    setState(() => selectedImage = null);
                    await loadPlants();
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

  // ── EDIT PLANT DIALOG ───────────────────────────────────────────
  void showEditPlantDialog(PlantModel plant) {
    final plantController = TextEditingController(text: plant.plant);
    final scientificController = TextEditingController(text: plant.scientific);
    final tunisianController = TextEditingController(text: plant.tunisianName);
    final imageController = TextEditingController(text: plant.preview);
    final descController = TextEditingController(text: plant.description);
    String type = plant.type.split(RegExp(r'[•,;/]')).first.trim();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit ${plant.plant}"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: plantController,
                        decoration: const InputDecoration(
                          labelText: "Plant Name",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scientificController,
                        decoration: const InputDecoration(
                          labelText: "Scientific Name",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tunisianController,
                        decoration: const InputDecoration(
                          labelText: "Tunisian Name",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: "Image URL",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Description",
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(labelText: "Type"),
                        items: availableTypes
                            .where((e) => e != "All")
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => type = value!),
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
                    if (plantController.text.isEmpty ||
                        scientificController.text.isEmpty)
                      return;

                    Navigator.pop(context);
                    await editPlant(plant.id, {
                      'plantName': plantController.text,
                      'scientificName': scientificController.text,
                      'tunisianName': tunisianController.text,
                      'imageUrl': imageController.text,
                      'description': descController.text,
                      'plantType': type,
                    });
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
              "Plants",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => filterPlants(),
                    decoration: InputDecoration(
                      hintText: "Search plant...",
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
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: availableTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedType = value!);
                      loadPlants();
                    },
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: loadPlants,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: showAddPlantDialog, // ← ADD PLANT BUTTON
                  icon: const Icon(Icons.add),
                  label: const Text("Add Plant"),
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
                        onPressed: loadPlants,
                        child: const Text("Retry"),
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
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 60,
                        dataRowHeight: 80,
                        columnSpacing: 35,
                        horizontalMargin: 20,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        columns: const [
                          DataColumn(label: Text("Image")),
                          DataColumn(label: Text("Plant")),
                          DataColumn(label: Text("Scientific")),
                          DataColumn(label: Text("Tunisian")),
                          DataColumn(label: Text("Type")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: filteredPlants.map((plant) {
                          return DataRow(
                            cells: [
                              DataCell(
                                CircleAvatar(
                                  radius: 25,
                                  backgroundImage: plant.preview.isNotEmpty
                                      ? NetworkImage(plant.preview)
                                      : null,
                                  child: plant.preview.isEmpty
                                      ? const Icon(Icons.local_florist)
                                      : null,
                                ),
                              ),
                              DataCell(
                                Text(
                                  plant.plant,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(plant.scientific)),
                              DataCell(Text(plant.tunisianName)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    plant.type
                                        .split(RegExp(r'[•,;/]'))
                                        .first
                                        .trim(),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          showEditPlantDialog(plant),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text("Edit"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: () => deletePlant(plant),
                                      icon: const Icon(Icons.delete, size: 18),
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
