import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const CleanerApp());

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: const Color(0xFF00D2FF),
      ),
      home: const ActivationScreen(),
    );
  }
}

// 1. شاشة التفعيل
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();

  void _checkActivation() {
    if (_codeController.text.trim() == "Maloohm123") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainCleanerScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("INVALID KEY")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, size: 100, color: Color(0xFF00D2FF)),
              const SizedBox(height: 30),
              const Text("AI SYSTEM ACCESS", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 40),
              TextField(
                controller: _codeController, 
                decoration: InputDecoration(
                  filled: true, fillColor: Colors.white10, hintText: "Enter Activation Key",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                )
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _checkActivation, child: const Text("INITIALIZE SYSTEM"))),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. الشاشة الرئيسية الاحترافية
class MainCleanerScreen extends StatefulWidget {
  const MainCleanerScreen({super.key});
  @override
  State<MainCleanerScreen> createState() => _MainCleanerScreenState();
}

class _MainCleanerScreenState extends State<MainCleanerScreen> with SingleTickerProviderStateMixin {
  int _deletedCount = 0;
  bool _isScanning = false;
  String _currentStatus = "Ready to Optimize";
  List<String> _logs = ["System Initialized..."];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  void _addLog(String msg) {
    setState(() {
      _logs.insert(0, "[AI] $msg");
      if (_logs.length > 5) _logs.removeLast();
    });
  }

  Future<void> _performCleanup() async {
    setState(() { _isScanning = true; _currentStatus = "Analyzing Storage..."; });
    _addLog("Permission requested...");
    
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      _addLog("Scanning directories...");
      Directory root = Directory('/storage/emulated/0/');
      
      void deleteThumbnails(Directory dir) {
        try {
          List<FileSystemEntity> entities = dir.listSync();
          for (var entity in entities) {
            if (entity is Directory && entity.path.toLowerCase().contains('thumbnails')) {
              _addLog("Cleaning: ${entity.path.split('/').last}");
              entity.listSync().forEach((file) {
                if (file is File) {
                  try { file.deleteSync(); setState(() => _deletedCount++); } catch (_) {}
                }
              });
            } else if (entity is Directory) {
              deleteThumbnails(entity);
            }
          }
        } catch (_) {}
      }
      deleteThumbnails(root);
      _addLog("Optimization Complete.");
      setState(() => _currentStatus = "Optimization Complete!");
    }
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI OPTIMIZER"), centerTitle: true, backgroundColor: Colors.transparent),
      body: Column(
        children: [
          const SizedBox(height: 30),
          ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.05).animate(_controller),
            child: const Icon(Icons.psychology, size: 100, color: Color(0xFF00D2FF)),
          ),
          const SizedBox(height: 20),
          Text(_currentStatus, style: const TextStyle(fontSize: 18, color: Colors.blueAccent)),
          Text("$_deletedCount", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          const Text("FILES CLEANED", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          
          Expanded(child: ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (context, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(_logs[i], style: const TextStyle(color: Colors.greenAccent))),
          )),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _performCleanup,
              icon: const Icon(Icons.cleaning_services),
              label: const Text("RUN DEEP CLEAN", style: TextStyle(fontSize: 18)),
            )),
          ),
        ],
      ),
    );
  }
}
