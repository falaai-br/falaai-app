import 'package:flutter/material.dart';

void main() {
  runApp(const FalaAiApp());
}

/// Casca mínima do app. Estado, rotas e textos em ARB chegam com o esqueleto.
class FalaAiApp extends StatelessWidget {
  const FalaAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold());
  }
}
