import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  void _doLogin() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(_email.text.trim(), _password.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/campus_bg.jpg'), fit: BoxFit.cover))),
        Container(color: Colors.black.withOpacity(0.45)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.navigation, size: 72, color: Colors.indigo),
                  const SizedBox(height: 8),
                  const Text('CogniFind', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 12),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _doLogin,
                    icon: const Icon(Icons.login),
                    label: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Login'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('Create account')),
                ]),
              ),
            ),
          ),
        )
      ]),
    );
  }
}
