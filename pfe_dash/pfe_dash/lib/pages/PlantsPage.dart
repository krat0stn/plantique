import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Lightweight reference to an AR/3-D model – only what PlantsPage needs.
class ArModelRef {
  final String id;
  final String name;
  final String plantName;
  final String glbUrl;
  final String thumbUrl;

  ArModelRef({
    required this.id,
    required this.name,
    required this.plantName,
    required this.glbUrl,
    required this.thumbUrl,
  });

  factory ArModelRef.fromJson(Map<String, dynamic> json) => ArModelRef(
    id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    plantName: json['plantName']?.toString() ?? '',
    glbUrl: json['glbUrl']?.toString() ?? '',
    thumbUrl: json['thumbUrl']?.toString() ?? '',
  );
}

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

  // ── plant image ──
  PlatformFile? selectedImage;

  // ── 3-D model files (used inside dialogs) ──
  PlatformFile? selectedModelFile;
  PlatformFile? selectedThumbFile;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController typeFilterController = TextEditingController();
  String selectedType = "All";
  List<String> availableTypes = ["All"];

  // ── 3-D model index keyed by plant name (lowercase) ─────────────
  List<ArModelRef> arModels = [];

  @override
  void initState() {
    super.initState();
    loadTypes();
    loadPlants();
    loadArModels();
  }

  Future<void> loadArModels() async {
    try {
      final data = await ApiService.get('/ar');
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        arModels = list.map((m) => ArModelRef.fromJson(m)).toList();
      });
    } catch (_) {
      // Best-effort – 3-D preview is optional
    }
  }

  /// Returns the first AR model whose plantName matches [plant.plant],
  /// or null if none exists.
  ArModelRef? _modelFor(PlantModel plant) {
    final name = plant.plant.toLowerCase();
    try {
      return arModels.firstWhere((m) => m.plantName.toLowerCase() == name);
    } catch (_) {
      return null;
    }
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

  // ── 3D PREVIEW DIALOG ───────────────────────────────────────────
  void show3DPreviewDialog(PlantModel plant, ArModelRef model) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.view_in_ar, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '3D Model – ${plant.plant}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── live 3D model viewer ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: model.glbUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: ModelViewer(
                            key: ValueKey(model.glbUrl),
                            backgroundColor: const Color(0xFFEFF6F4),
                            src: model.glbUrl,
                            alt: '3D model of ${plant.plant}',
                            autoRotate: true,
                            cameraControls: true,
                            disableZoom: false,
                          ),
                        ),
                      )
                    : Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.view_in_ar,
                              size: 64,
                              color: Color(0xFF00796B),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No 3D model file available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
              ),

              // ── model info ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.label_outline, 'Model name', model.name),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.local_florist_outlined,
                      'Linked plant',
                      model.plantName,
                    ),
                    if (model.glbUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.insert_drive_file_outlined,
                        'GLB file',
                        model.glbUrl.length > 50
                            ? '...${model.glbUrl.substring(model.glbUrl.length - 50)}'
                            : model.glbUrl,
                      ),
                    ],
                  ],
                ),
              ),

              // ── close button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.teal),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── ADD PLANT ───────────────────────────────────────────────────
  Future<void> addPlant(
    Map<String, String> fields, {
    PlatformFile? image,
  }) async {
    try {
      final files = <http.MultipartFile>[];
      if (image != null && image.bytes != null) {
        files.add(
          http.MultipartFile.fromBytes(
            'image',
            image.bytes!,
            filename: image.name,
          ),
        );
      }
      await ApiService.multipartRequest(
        'POST',
        '/admin/plant-care',
        fields,
        files,
      );
      await loadPlants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plant added successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to add plant: $e")));
      }
    }
  }

  // ── EDIT PLANT ──────────────────────────────────────────────────
  Future<void> editPlant(
    String id,
    Map<String, String> fields, {
    PlatformFile? image,
  }) async {
    try {
      final files = <http.MultipartFile>[];
      if (image != null && image.bytes != null) {
        files.add(
          http.MultipartFile.fromBytes(
            'image',
            image.bytes!,
            filename: image.name,
          ),
        );
      }
      await ApiService.multipartRequest(
        'PUT',
        '/admin/plant-care/$id',
        fields,
        files,
      );
      await loadPlants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plant updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update plant: $e")));
      }
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
    if (result != null) setState(() => selectedImage = result.files.first);
  }

  Future<void> pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf'],
      withData: true,
    );
    if (result != null) setState(() => selectedModelFile = result.files.first);
  }

  Future<void> pickThumbFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => selectedThumbFile = result.files.first);
  }

  List<http.MultipartFile> _buildModelFiles() {
    final files = <http.MultipartFile>[];
    if (selectedModelFile != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'model',
          selectedModelFile!.bytes!,
          filename: selectedModelFile!.name,
        ),
      );
    }
    if (selectedThumbFile != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'thumbnail',
          selectedThumbFile!.bytes!,
          filename: selectedThumbFile!.name,
        ),
      );
    }
    return files;
  }

  // ── SAVE (add or update) AR model linked to a plant ─────────────
  Future<void> saveArModel({
    required String plantName,
    String? existingId,
  }) async {
    if (existingId == null && selectedModelFile == null) return;
    try {
      final fields = {'name': plantName, 'plantName': plantName, 'tags': ''};
      if (existingId != null) {
        await ApiService.multipartRequest(
          'PUT',
          '/ar/$existingId',
          fields,
          _buildModelFiles(),
        );
      } else {
        await ApiService.multipartRequest(
          'POST',
          '/ar',
          fields,
          _buildModelFiles(),
        );
      }
      await loadArModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('3D model save failed: $e')));
      }
    } finally {
      selectedModelFile = null;
      selectedThumbFile = null;
    }
  }

  Future<void> deleteArModel(String id) async {
    try {
      await ApiService.delete('/ar/$id');
      await loadArModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete 3D model: $e')),
        );
      }
    }
  }

  // ── ADD PLANT DIALOG ────────────────────────────────────────────
  void showAddPlantDialog() {
    final plantController = TextEditingController();
    final scientificController = TextEditingController();
    final tunisianController = TextEditingController();
    final descController = TextEditingController();
    final typeController = TextEditingController();
    selectedModelFile = null;
    selectedThumbFile = null;
    selectedImage = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Plant"),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Plant image ──
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickImage();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          selectedImage == null
                              ? 'Pick Plant Image'
                              : 'Image: ${selectedImage!.name}',
                        ),
                      ),
                      const SizedBox(height: 15),

                      // ── Core fields ──
                      TextField(
                        controller: plantController,
                        decoration: const InputDecoration(
                          labelText: 'Plant Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scientificController,
                        decoration: const InputDecoration(
                          labelText: 'Scientific Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tunisianController,
                        decoration: const InputDecoration(
                          labelText: 'Tunisian Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: typeController,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      // ── 3D Model section (optional) ──
                      const SizedBox(height: 20),
                      const Divider(),
                      Row(
                        children: const [
                          Icon(
                            Icons.view_in_ar,
                            size: 18,
                            color: Color(0xFF00796B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '3D Model (optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await pickModelFile();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.view_in_ar, size: 16),
                              label: Text(
                                selectedModelFile == null
                                    ? 'Pick .glb/.gltf'
                                    : selectedModelFile!.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await pickThumbFile();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.image, size: 16),
                              label: Text(
                                selectedThumbFile == null
                                    ? 'Pick Thumbnail'
                                    : selectedThumbFile!.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (selectedModelFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '✓ Model file ready: ${selectedModelFile!.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selectedModelFile = null;
                    selectedThumbFile = null;
                    selectedImage = null;
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (plantController.text.isEmpty ||
                        scientificController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Plant name and Scientific name are required',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    await addPlant({
                      'plantName': plantController.text,
                      'scientificName': scientificController.text,
                      'tunisianName': tunisianController.text,
                      'description': descController.text,
                      'plantType': typeController.text,
                      'slug': plantController.text.toLowerCase().replaceAll(
                        ' ',
                        '-',
                      ),
                    }, image: selectedImage);
                    setState(() => selectedImage = null);

                    if (selectedModelFile != null) {
                      await saveArModel(plantName: plantController.text);
                    }
                  },
                  child: const Text('Add'),
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
    final descController = TextEditingController(text: plant.description);
    // FIX: preserve the FULL type string, not just the first one
    final typeController = TextEditingController(text: plant.type);
    selectedModelFile = null;
    selectedThumbFile = null;
    selectedImage = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final existingModel = _modelFor(plant);

            return AlertDialog(
              title: Text('Edit ${plant.plant}'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Core fields ──
                      TextField(
                        controller: plantController,
                        decoration: const InputDecoration(
                          labelText: 'Plant Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scientificController,
                        decoration: const InputDecoration(
                          labelText: 'Scientific Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tunisianController,
                        decoration: const InputDecoration(
                          labelText: 'Tunisian Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Plant image ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: selectedImage != null
                                ? Image.memory(
                                    selectedImage!.bytes!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : (plant.preview.isNotEmpty
                                      ? Image.network(
                                          plant.preview,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.local_florist,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.local_florist,
                                          ),
                                        )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await pickImage();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.image),
                              label: Text(
                                selectedImage == null
                                    ? 'Select Image'
                                    : 'Image: ${selectedImage!.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: typeController,
                        decoration: const InputDecoration(labelText: 'Type'),
                      ),

                      // ── 3D Model section ──
                      const SizedBox(height: 20),
                      const Divider(),
                      Row(
                        children: const [
                          Icon(
                            Icons.view_in_ar,
                            size: 18,
                            color: Color(0xFF00796B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '3D Model',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (existingModel != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (existingModel.thumbUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        existingModel.thumbUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.view_in_ar,
                                              size: 40,
                                              color: Colors.teal,
                                            ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.view_in_ar,
                                      size: 40,
                                      color: Colors.teal,
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          existingModel.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (existingModel.glbUrl.isNotEmpty)
                                          Text(
                                            existingModel.glbUrl.length > 40
                                                ? '...${existingModel.glbUrl.substring(existingModel.glbUrl.length - 40)}'
                                                : existingModel.glbUrl,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await pickModelFile();
                                        setDialogState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 16,
                                      ),
                                      label: Text(
                                        selectedModelFile == null
                                            ? 'Replace .glb/.gltf'
                                            : selectedModelFile!.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF00796B,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await pickThumbFile();
                                        setDialogState(() {});
                                      },
                                      icon: const Icon(Icons.image, size: 16),
                                      label: Text(
                                        selectedThumbFile == null
                                            ? 'Replace Thumbnail'
                                            : selectedThumbFile!.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Delete 3D model',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete 3D model?'),
                                          content: const Text(
                                            'This will remove the 3D model linked to this plant.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await deleteArModel(existingModel.id);
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await pickModelFile();
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.view_in_ar, size: 16),
                                label: Text(
                                  selectedModelFile == null
                                      ? 'Add .glb/.gltf'
                                      : selectedModelFile!.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await pickThumbFile();
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.image, size: 16),
                                label: Text(
                                  selectedThumbFile == null
                                      ? 'Add Thumbnail'
                                      : selectedThumbFile!.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (selectedModelFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '✓ Model ready: ${selectedModelFile!.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00796B),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selectedModelFile = null;
                    selectedThumbFile = null;
                    selectedImage = null;
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (plantController.text.isEmpty ||
                        scientificController.text.isEmpty)
                      return;

                    Navigator.pop(context);

                    // FIX: include slug so it updates when name changes
                    final Map<String, String> fields = {
                      'plantName': plantController.text,
                      'scientificName': scientificController.text,
                      'tunisianName': tunisianController.text,
                      'description': descController.text,
                      'plantType': typeController.text,
                      'slug': plantController.text.toLowerCase().replaceAll(
                        ' ',
                        '-',
                      ),
                    };
                    await editPlant(plant.id, fields, image: selectedImage);
                    setState(() => selectedImage = null);

                    final model = _modelFor(plant);
                    if (selectedModelFile != null ||
                        selectedThumbFile != null) {
                      await saveArModel(
                        plantName: plantController.text,
                        existingId: model?.id,
                      );
                    }
                  },
                  child: const Text('Save'),
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
                  child: TextField(
                    controller: typeFilterController,
                    onChanged: (value) {
                      setState(
                        () => selectedType = value.isEmpty ? "All" : value,
                      );
                      filterPlants();
                    },
                    decoration: InputDecoration(
                      hintText: "Filter by type...",
                      prefixIcon: const Icon(Icons.category_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
                  onPressed: showAddPlantDialog,
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
                                    Builder(
                                      builder: (context) {
                                        final model = _modelFor(plant);
                                        if (model == null)
                                          return const SizedBox.shrink();
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                show3DPreviewDialog(
                                                  plant,
                                                  model,
                                                ),
                                            icon: const Icon(
                                              Icons.view_in_ar,
                                              size: 18,
                                            ),
                                            label: const Text("Preview 3D"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF00796B,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
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
