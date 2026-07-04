import 'package:flutter/material.dart';

void main() {
  runApp(const CleanerApp());
}

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleaner App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Cleaner App')),
        body: const Center(child: Text('Hello, Flutter!')),
      ),
    );
  }
}
