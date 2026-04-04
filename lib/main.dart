import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login/login_screen.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Qontract',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
          useMaterial3: true,
        ),
        home: LoginScreen(),
      ),
    );
  }
}
