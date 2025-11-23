import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'route_map_screen.dart';
import 'admin_users_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CogniFindApp());
}

class CogniFindApp extends StatelessWidget {
  const CogniFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniFind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),

      // Start at Splash always
      home: const SplashScreen(),

      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/map': (_) => const RouteMapScreen(),
        '/admin/users': (_) => const AdminUsersScreen(),
      },
    );
  }
}
