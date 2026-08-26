import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final double price;
  final DateTime eventDate;
  final String imageUrl;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    required this.eventDate,
    required this.imageUrl,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['eventDate']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return EventModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price'].toString()) ?? 0.0,
      eventDate: parsedDate,
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<EventModel> events = [];
  bool loading = true;
  String? error;
  PlatformFile? selectedImage;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await ApiService.get('/admin/events');
      final List<dynamic> list = data['data'] ?? [];
      setState(() {
        events = list.map((e) => EventModel.fromJson(e)).toList();
      });
    } catch (e) {
      setState(() => error = 'Failed to load events: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => selectedImage = result.files.first);
  }

  List<http.MultipartFile> _buildFiles() {
    if (selectedImage == null) return [];
    return [
      http.MultipartFile.fromBytes(
        'image',
        selectedImage!.bytes!,
        filename: selectedImage!.name,
      ),
    ];
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required String location,
    required String price,
    required String eventDate,
  }) async {
    try {
      await ApiService.multipartRequest(
        'POST',
        '/admin/events',
        {
          'title': title,
          'description': description,
          'location': location,
          'price': price,
          'eventDate': eventDate,
        },
        _buildFiles(),
      );
      selectedImage = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created')),
        );
      }
      await loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> updateEvent(
    String eventId, {
    required String title,
    required String description,
    required String location,
    required String price,
    required String eventDate,
  }) async {
    try {
      await ApiService.multipartRequest(
        'PUT',
        '/admin/events/$eventId',
        {
          'title': title,
          'description': description,
          'location': location,
          'price': price,
          'eventDate': eventDate,
        },
        _buildFiles(),
      );
      selectedImage = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated')),
        );
      }
      await loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> deleteEvent(EventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      await ApiService.delete('/admin/events/${event.id}');
      setState(() => events.removeWhere((e) => e.id == event.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${event.title}" deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showEventDialog({EventModel? event}) {
    final titleCtrl = TextEditingController(text: event?.title ?? '');
    final descriptionCtrl = TextEditingController(text: event?.description ?? '');
    final locationCtrl = TextEditingController(text: event?.location ?? '');
    final priceCtrl = TextEditingController(
      text: event?.price.toString() ?? '0',
    );
    DateTime? selectedDate = event?.eventDate;
    selectedImage = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(event == null ? 'New Event' : 'Edit Event'),
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
                    label: Text(
                      selectedImage == null
                          ? 'Pick image (optional)'
                          : 'Image: ${selectedImage!.name}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _field(titleCtrl, 'Title *'),
                  const SizedBox(height: 12),
                  _field(descriptionCtrl, 'Description', maxLines: 3),
                  const SizedBox(height: 12),
                  _field(locationCtrl, 'Location'),
                  const SizedBox(height: 12),
                  _field(
                    priceCtrl,
                    'Price',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Event Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        selectedDate != null
                            ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                        style: TextStyle(
                          color:
                              selectedDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title is required')),
                  );
                  return;
                }
                if (selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event date is required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final dateStr = selectedDate!.toIso8601String();
                if (event == null) {
                  await createEvent(
                    title: titleCtrl.text.trim(),
                    description: descriptionCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                    price: priceCtrl.text.trim(),
                    eventDate: dateStr,
                  );
                } else {
                  await updateEvent(
                    event.id,
                    title: titleCtrl.text.trim(),
                    description: descriptionCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                    price: priceCtrl.text.trim(),
                    eventDate: dateStr,
                  );
                }
              },
              child: Text(event == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
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
                  'Events',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: loadEvents,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showEventDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Event'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: loadEvents,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (events.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No events yet. Click "New Event" to add one.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
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
                            const Color.fromARGB(186, 234, 143, 143)
                                .withValues(alpha: 0.3),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Title',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Location',
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
                                'Event Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: events.map((e) {
                            final dateStr =
                                '${e.eventDate.year}-${e.eventDate.month.toString().padLeft(2, '0')}-${e.eventDate.day.toString().padLeft(2, '0')}';
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    e.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DataCell(Text(e.location.isEmpty ? '—' : e.location)),
                                DataCell(
                                  Text(
                                    '\$${e.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(dateStr),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _showEventDialog(event: e),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete',
                                        onPressed: () => deleteEvent(e),
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
              ),
          ],
        ),
      ),
    );
  }
}
