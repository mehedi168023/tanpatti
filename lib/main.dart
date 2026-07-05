import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const RecoverTeenPattiApp());
}

class RecoverTeenPattiApp extends StatelessWidget {
  const RecoverTeenPattiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recover TeenPatti',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0B6B3A),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
