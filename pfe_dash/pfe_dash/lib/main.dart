import 'package:flutter/material.dart';
import 'home.dart';
import 'supplier_home.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _adminEmailCtrl    = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _supplierEmailCtrl    = TextEditingController();
  final _supplierPasswordCtrl = TextEditingController();

  bool _adminLoading    = false;
  bool _supplierLoading = false;
  String? _adminError;
  String? _supplierError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminEmailCtrl.dispose();
    _adminPasswordCtrl.dispose();
    _supplierEmailCtrl.dispose();
    _supplierPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _adminLogin() async {
    setState(() { _adminLoading = true; _adminError = null; });
    try {
      final response = await ApiService.post('/auth/signin', {
        'email': _adminEmailCtrl.text,
        'password': _adminPasswordCtrl.text,
      });
      final token = response['token'];
      if (token != null) ApiService.setToken(token);

      final user = response['user'];
      if (user != null) {
        final role = user['role']?.toString() ?? 'User';
        ApiService.setIsAdmin(role == 'Admin');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() => _adminError = 'Login failed: ${e.toString()}');
    } finally {
      setState(() => _adminLoading = false);
    }
  }

  Future<void> _supplierLogin() async {
    setState(() { _supplierLoading = true; _supplierError = null; });
    try {
      final response = await ApiService.post('/auth/supplier-signin', {
        'email': _supplierEmailCtrl.text,
        'password': _supplierPasswordCtrl.text,
      });
      final token = response['token'];
      if (token != null) {
        ApiService.setToken(token);
        ApiService.setIsAdmin(false);
        ApiService.setRole('Supplier');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SupplierHomePage()),
        );
      }
    } catch (e) {
      setState(() => _supplierError = 'Login failed: ${e.toString()}');
    } finally {
      setState(() => _supplierLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 620,
          height: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              const Expanded(child: _PictureSide()),
              Expanded(
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      color: const Color.fromARGB(186, 234, 143, 143),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: Colors.white,
                        tabs: const [
                          Tab(text: 'Admin Login'),
                          Tab(text: 'Supplier Login'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Admin tab
                          _LoginFormSide(
                            emailController: _adminEmailCtrl,
                            passwordController: _adminPasswordCtrl,
                            onLogin: _adminLogin,
                            loading: _adminLoading,
                            error: _adminError,
                            buttonLabel: 'Sign In as Admin',
                          ),
                          // Supplier tab
                          _LoginFormSide(
                            emailController: _supplierEmailCtrl,
                            passwordController: _supplierPasswordCtrl,
                            onLogin: _supplierLogin,
                            loading: _supplierLoading,
                            error: _supplierError,
                            buttonLabel: 'Sign In as Supplier',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PictureSide extends StatelessWidget {
  const _PictureSide();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color.fromARGB(186, 234, 143, 143),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Center(
        child: Image.asset(
          "assets/images/logo.png",
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _LoginFormSide extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final bool loading;
  final String? error;
  final String buttonLabel;

  const _LoginFormSide({
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.loading,
    required this.buttonLabel,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Login",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: loading ? null : onLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color.fromARGB(186, 234, 143, 143),
            ),
            child: loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(buttonLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
