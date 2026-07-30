import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String? profilePic;
  final String status;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.profilePic,
    required this.status,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      profilePic: json['picture'],
      status: json['status'] ?? 'Active',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<UserModel> users = [];
  List<UserModel> filteredUsers = [];
  bool loading = true;
  String? error;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('Current token: ${ApiService.token}');
    loadUsers();
  }

  // ── LOAD USERS FROM API ─────────────────────────────────────────
  Future<void> loadUsers() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.get('/users');
      print('RAW API RESPONSE: $data'); // ← ADD THIS
      print('Response type: ${data.runtimeType}'); // ← ADD THIS

      final List<dynamic> userList = data is List
          ? data
          : data['users'] ?? data['data'] ?? [];
      print('PARSED USER LIST: $userList'); // ← ADD THIS
      print('User count: ${userList.length}'); // ← ADD THIS

      users = userList.map((u) {
        print('Processing user: $u'); // ← ADD THIS
        return UserModel.fromJson(u);
      }).toList();

      filteredUsers = List.from(users);
      print('FINAL USERS COUNT: ${users.length}'); // ← ADD THIS
    } catch (e) {
      print('ERROR: $e'); // ← ADD THIS
      setState(() => error = 'Failed to load users: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ── DELETE USER FROM API ──────────────────────────────────────
  Future<void> deleteUser(UserModel user) async {
    try {
      await ApiService.delete('/users/${user.id}');

      setState(() {
        users.removeWhere((u) => u.id == user.id);
        filteredUsers.removeWhere((u) => u.id == user.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${user.username} deleted")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  // ── EDIT USER (SHOW DIALOG + API CALL) ────────────────────────
  Future<void> editUser(UserModel user) async {
    final nameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    String selectedStatus = user.status;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit ${user.username}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(labelText: "Status"),
              items: ['Active', 'Inactive', 'Banned'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) => selectedStatus = value!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'username': nameController.text,
              'email': emailController.text,
              'status': selectedStatus,
            }),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ApiService.put('/users/${user.id}', result);

        // Reload to get updated data
        await loadUsers();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${user.username} updated")));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
      }
    }
  }

  void searchUser(String value) {
    setState(() {
      filteredUsers = users.where((user) {
        return user.username.toLowerCase().contains(value.toLowerCase()) ||
            user.email.toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  Color statusColor(String status) {
    switch (status) {
      case "Active":
        return Colors.green;
      case "Inactive":
        return Colors.orange;
      case "Banned":
        return Colors.red;
      default:
        return Colors.grey;
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
            const Text(
              "Users",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: searchUser,
                    decoration: InputDecoration(
                      hintText: "Search user...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: loadUsers,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
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
                        onPressed: loadUsers,
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
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 60,
                      dataRowHeight: 70,
                      columnSpacing: 40,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                      columns: const [
                        DataColumn(label: Text("Username")),
                        DataColumn(label: Text("Email")),
                        DataColumn(label: Text("ProfilePic")),
                        DataColumn(label: Text("Status")),
                        DataColumn(label: Text("Created")),
                        DataColumn(label: Text("Actions")),
                      ],
                      rows: filteredUsers.map((user) {
                        return DataRow(
                          cells: [
                            DataCell(Text(user.username)),
                            DataCell(Text(user.email)),
                            DataCell(
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: user.profilePic != null
                                    ? NetworkImage(user.profilePic!)
                                    : null,
                                child: user.profilePic == null
                                    ? Text(user.username[0].toUpperCase())
                                    : null,
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor(
                                    user.status,
                                  ).withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  user.status,
                                  style: TextStyle(
                                    color: statusColor(user.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}",
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => editUser(user),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text("Edit"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => deleteUser(user),
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
          ],
        ),
      ),
    );
  }
}
