import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const CleanerApp());
}

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: const Color(0xFF00D2FF), // لون النيون الأزرق
      ),
      home: const ActivationScreen(),
    );
  }
}

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();

  void _checkActivation() {
    if (_codeController.text == "AI2026") { // كود مستقبلي
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainCleanerScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, size: 80, color: Color(0xFF00D2FF)),
              const SizedBox(height: 20),
              const Text("AI SYSTEM ACCESS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 30),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  hintText: "Enter Neural Key",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkActivation,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2FF)),
                child: const Text("INITIALIZE SYSTEM", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainCleanerScreen extends StatefulWidget {
  const MainCleanerScreen({super.key});

  @override
  State<MainCleanerScreen> createState() => _MainCleanerScreenState();
}

class _MainCleanerScreenState extends State<MainCleanerScreen> {
  bool _isScanning = false;

  Future<void> _runAIProcess() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 3)); // محاكاة تحليل الذكاء الاصطناعي
    setState(() => _isScanning = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("SYSTEM OPTIMIZED: 2.4GB Freed by AI"),
        backgroundColor: Color(0xFF00D2FF),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              height: _isScanning ? 150 : 100,
              width: _isScanning ? 150 : 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent,
                border: Border.all(color: const Color(0xFF00D2FF), width: 3),
              ),
              child: const Icon(Icons.memory, size: 50, color: Color(0xFF00D2FF)),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _runAIProcess,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: const Color(0xFF00D2FF),
              ),
              child: _isScanning 
                ? const CircularProgressIndicator(color: Colors.black) 
                : const Text("ENGAGE AI CLEANER", style: TextStyle(color: Colors.black, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
