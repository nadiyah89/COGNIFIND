import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'route_map_screen.dart';
import 'admin_users_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _name = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await AuthService.instance.getName();
    final role = await AuthService.instance.getRole();
    setState(() {
      _name = name ?? '';
      _role = role ?? '';
    });
  }

  void _logout() async {
    await AuthService.instance.clear();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CogniFind'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/campus_bg.jpg'), fit: BoxFit.cover))),
          Container(color: Colors.black.withOpacity(0.35)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Welcome, ${_name.isEmpty ? 'Student' : _name}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Start Navigation'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteMapScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30)),
                ),
                const SizedBox(height: 12),
                if (_role == 'Admin' || _role == 'SuperAdmin')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin: Manage Users'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  ),
              ]),
            ),
          )
        ],
      ),
    );
  }
}
