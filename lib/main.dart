import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

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
    // المفتاح النهائي
    if (_codeController.text == "Maloohm123") {
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, size: 80, color: Color(0xFF00D2FF)),
              const Text("AI SYSTEM ACCESS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(controller: _codeController, decoration: const InputDecoration(filled: true, fillColor: Colors.white10, hintText: "Enter Key")),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _checkActivation, child: const Text("INITIALIZE SYSTEM")),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. الشاشة الرئيسية
class MainCleanerScreen extends StatefulWidget {
  const MainCleanerScreen({super.key});
  @override
  State<MainCleanerScreen> createState() => _MainCleanerScreenState();
}

class _MainCleanerScreenState extends State<MainCleanerScreen> {
  int _deletedCount = 0;
  bool _isScanning = false;

  Future<void> _performCleanup() async {
    setState(() => _isScanning = true);
    var status = await Permission.manageExternalStorage.request();
    
    if (status.isGranted) {
      Directory root = Directory('/storage/emulated/0/');
      void deleteThumbnails(Directory dir) {
        try {
          List<FileSystemEntity> entities = dir.listSync();
          for (var entity in entities) {
            if (entity is Directory && entity.path.toLowerCase().contains('thumbnails')) {
              entity.listSync().forEach((file) {
                if (file is File) {
                  file.deleteSync();
                  setState(() => _deletedCount++);
                }
              });
            } else if (entity is Directory) {
              deleteThumbnails(entity);
            }
          }
        } catch (_) {}
      }
      deleteThumbnails(root);
    }
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI OPTIMIZER")),
      body: Column(
        children: [
          const SizedBox(height: 50),
          Text("FILES REMOVED: $_deletedCount", style: const TextStyle(fontSize: 30, color: Color(0xFF00D2FF))),
          const SizedBox(height: 20),
          _isScanning 
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: _performCleanup, child: const Text("ENGAGE AI CLEANER")),
          const Divider(),
          const Text("MANUAL SYSTEM CLEANUP:"),
          ListTile(
            title: const Text("Clear App Cache Settings"),
            leading: const Icon(Icons.settings_applications),
            onTap: () => AppSettings.openAppSettings(type: AppSettingsType.settings),
          ),
        ],
      ),
    );
  }
}
