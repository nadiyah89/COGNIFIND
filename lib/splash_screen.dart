import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();
    _navigate();
  }

  void _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await AuthService.instance.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade600,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.navigation, size: 110, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                "CogniFind",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your Smart Campus Guide",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
