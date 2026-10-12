import 'package:flutter/material.dart';

import 'numeros_iniciales_screen.dart';

void main() {
  runApp(const BrilliantApp());
}

class BrilliantApp extends StatelessWidget {
  const BrilliantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brilliant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E5CF0),
          brightness: Brightness.dark,
        ),
      ),
      home: const NumerosInicialesScreen(),
    );
  }
}