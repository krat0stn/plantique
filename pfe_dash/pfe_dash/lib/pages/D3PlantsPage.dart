import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class ArModel {
  final String id;
  final String name;
  final String plantName;
  final String glbUrl;
  final String thumbUrl;
  final List<String> tags;
  final DateTime updatedAt;

  ArModel({
    required this.id,
    required this.name,
    required this.plantName,
    required this.glbUrl,
    required this.thumbUrl,
    required this.tags,
    required this.updatedAt,
  });

  factory ArModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['updatedAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ArModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      plantName: json['plantName']?.toString() ?? '',
      glbUrl: json['glbUrl']?.toString() ?? '',
      thumbUrl: json['thumbUrl']?.toString() ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ??
          [],
      updatedAt: parsedDate,
    );
  }
}

class D3PlantsPage extends StatefulWidget {
  const D3PlantsPage({super.key});

  @override
  State<D3PlantsPage> createState() => _D3PlantsPageState();
}

class _D3PlantsPageState extends State<D3PlantsPage> {
  List<ArModel> models = [];
  List<ArModel> filteredModels = [];
  bool loading = true;
  String? error;

  final TextEditingController searchController = TextEditingController();

  PlatformFile? selectedModelFile;
  PlatformFile? selectedThumbFile;

  @override
  void initState() {
    super.initState();
    loadModels();
  }

  Future<void> loadModels({String q = ''}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final query = q.isNotEmpty ? '?q=${Uri.encodeQueryComponent(q)}' : '';
      final data = await ApiService.get('/ar$query');
      final List<dynamic> list = data['data'] ?? [];

      models = list.map((m) => ArModel.fromJson(m)).toList();
      filterModels();
    } catch (e) {
      setState(() => error = 'Failed to load 3D models: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void filterModels() {
    setState(() {
      final search = searchController.text.toLowerCase();
      filteredModels = models.where((m) {
        return m.name.toLowerCase().contains(search) ||
            m.plantName.toLowerCase().contains(search);
      }).toList();
    });
  }

  Future<void> pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf'],
      withData: true,
    );
    if (result != null) {
      setState(() => selectedModelFile = result.files.first);
    }
  }

  Future<void> pickThumbFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      setState(() => selectedThumbFile = result.files.first);
    }
  }

  List<http.MultipartFile> _buildFiles() {
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

  Future<void> addModel({
    required String name,
    required String plantName,
    required String tags,
  }) async {
    if (selectedModelFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A .glb or .gltf model file is required")),
      );
      return;
    }

    try {
      await ApiService.multipartRequest('POST', '/ar', {
        'name': name,
        'plantName': plantName,
        'tags': tags,
      }, _buildFiles());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("3D model added")));
      selectedModelFile = null;
      selectedThumbFile = null;
      await loadModels();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to add model: $e")));
    }
  }

  Future<void> editModel(
    ArModel model, {
    required String name,
    required String plantName,
    required String tags,
  }) async {
    try {
      await ApiService.multipartRequest('PUT', '/ar/${model.id}', {
        'name': name,
        'plantName': plantName,
        'tags': tags,
      }, _buildFiles());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("3D model updated")));
      selectedModelFile = null;
      selectedThumbFile = null;
      await loadModels();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update model: $e")));
    }
  }

  Future<void> deleteModel(ArModel model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete 3D model?"),
        content: Text("Delete \"${model.name}\"? This cannot be undone."),
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
      await ApiService.delete('/ar/${model.id}');
      setState(() {
        models.removeWhere((m) => m.id == model.id);
        filterModels();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${model.name} deleted")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  void showAddModelDialog() {
    final nameController = TextEditingController();
    final plantController = TextEditingController();
    final tagsController = TextEditingController();
    selectedModelFile = null;
    selectedThumbFile = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("New 3D Model"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickModelFile();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.view_in_ar),
                        label: Text(
                          selectedModelFile == null
                              ? "Pick .glb/.gltf file *"
                              : "Model: ${selectedModelFile!.name}",
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickThumbFile();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          selectedThumbFile == null
                              ? "Pick thumbnail (optional)"
                              : "Thumbnail: ${selectedThumbFile!.name}",
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Name *",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: plantController,
                        decoration: const InputDecoration(
                          labelText: "Plant Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagsController,
                        decoration: const InputDecoration(
                          labelText: "Tags (comma separated)",
                          border: OutlineInputBorder(),
                        ),
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
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Name is required")),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    await addModel(
                      name: nameController.text,
                      plantName: plantController.text,
                      tags: tagsController.text,
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

  void showEditModelDialog(ArModel model) {
    final nameController = TextEditingController(text: model.name);
    final plantController = TextEditingController(text: model.plantName);
    final tagsController = TextEditingController(text: model.tags.join(', '));
    selectedModelFile = null;
    selectedThumbFile = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit ${model.name}"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickModelFile();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.view_in_ar),
                        label: Text(
                          selectedModelFile == null
                              ? "Replace model file (optional)"
                              : "Model: ${selectedModelFile!.name}",
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickThumbFile();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: Text(
                          selectedThumbFile == null
                              ? "Replace thumbnail (optional)"
                              : "Thumbnail: ${selectedThumbFile!.name}",
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: plantController,
                        decoration: const InputDecoration(
                          labelText: "Plant Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagsController,
                        decoration: const InputDecoration(
                          labelText: "Tags (comma separated)",
                          border: OutlineInputBorder(),
                        ),
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
                    if (nameController.text.isEmpty) return;
                    Navigator.pop(context);
                    await editModel(
                      model,
                      name: nameController.text,
                      plantName: plantController.text,
                      tags: tagsController.text,
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

  void previewThumb(ArModel model) {
    if (model.thumbUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                model.thumbUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 300,
                  height: 300,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 60),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
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
              "3D Models (AR)",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (v) => loadModels(q: v),
                    decoration: InputDecoration(
                      hintText: "Search by name or plant name",
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
                  onPressed: () => loadModels(q: searchController.text),
                  child: const Text("Search"),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () => loadModels(q: searchController.text),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: showAddModelDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("New 3D Model"),
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
                        onPressed: () => loadModels(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredModels.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "No 3D models yet",
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
                        columnSpacing: 30,
                        horizontalMargin: 20,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        columns: const [
                          DataColumn(label: Text("Preview")),
                          DataColumn(label: Text("Name")),
                          DataColumn(label: Text("Plant")),
                          DataColumn(label: Text("File")),
                          DataColumn(label: Text("Updated")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: filteredModels.map((model) {
                          return DataRow(
                            cells: [
                              DataCell(
                                GestureDetector(
                                  onTap: () => previewThumb(model),
                                  child: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.green.shade50,
                                    backgroundImage: model.thumbUrl.isNotEmpty
                                        ? NetworkImage(model.thumbUrl)
                                        : null,
                                    child: model.thumbUrl.isEmpty
                                        ? const Icon(
                                            Icons.view_in_ar,
                                            color: Colors.green,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  model.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(model.plantName)),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    _truncate(model.glbUrl, 45),
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${model.updatedAt.month}/${model.updatedAt.day}/${model.updatedAt.year}, "
                                  "${model.updatedAt.hour.toString().padLeft(2, '0')}:${model.updatedAt.minute.toString().padLeft(2, '0')}",
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          showEditModelDialog(model),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text("Edit"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: () => deleteModel(model),
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
