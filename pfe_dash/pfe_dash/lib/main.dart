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

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Single sign-in call: the backend checks the Users collection first,
  // then the Suppliers collection, and tells us which one matched via
  // `user['role']`. We route to the matching dashboard - no manual
  // "login as admin / login as supplier" choice needed.
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.post('/auth/signin', {
        'email': _emailController.text,
        'password': _passwordController.text,
      });

      final token = response['token'];
      if (token != null) ApiService.setToken(token);

      final user = response['user'];
      final role = user != null ? (user['role']?.toString() ?? 'User') : 'User';
      ApiService.setRole(role);
      ApiService.setIsAdmin(role == 'Admin');

      if (!mounted) return;

      if (role == 'Supplier') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SupplierHomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Login failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 600,
          height: 450,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Expanded(child: _PictureSide()),
              Expanded(
                child: _LoginFormSide(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  onLogin: _login,
                  loading: _loading,
                  error: _error,
                  buttonLabel: 'Sign In',
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
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    buttonLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
