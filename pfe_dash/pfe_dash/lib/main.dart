import 'package:flutter/material.dart';
import 'home.dart';
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

      print('Full login response: $response');

      final token = response['token'];
      print('Token extracted: $token');
      if (token != null) {
        ApiService.setToken(token);
        print('Token saved successfully');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Login failed: ${e.toString()}';
      });
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
        color: Colors.blue,
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

  const _LoginFormSide({
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Login",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // ← CHANGED: removed const, added controller
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),

          const SizedBox(height: 20),

          // ← CHANGED: removed const, added controller
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),

          const SizedBox(height: 20),

          // ← ADDED: show error if any
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 10),

          // ← CHANGED: calls _login instead of direct navigation
          ElevatedButton(
            onPressed: loading ? null : onLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                : const Text("Sign In"),
          ),

          const SizedBox(height: 16),

          TextButton(onPressed: () {}, child: const Text("Forget Password?")),
        ],
      ),
    );
  }
}
