import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CleanerApp());
}

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleaner App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ActivationScreen(),
    );
  }
}

// شاشة التفعيل
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();

  void _checkActivation() {
    if (_codeController.text == "Maloohm123") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainCleanerScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود التفعيل غير صحيح!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل Cleaner App')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _codeController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'كود التفعيل')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _checkActivation, child: const Text('دخول')),
          ],
        ),
      ),
    );
  }
}

// الشاشة الرئيسية ووظيفة التنظيف
class MainCleanerScreen extends StatefulWidget {
  const MainCleanerScreen({super.key});

  @override
  State<MainCleanerScreen> createState() => _MainCleanerScreenState();
}

class _MainCleanerScreenState extends State<MainCleanerScreen> {
  bool _isCleaning = false;

  Future<void> _cleanThumbnails(BuildContext context) async {
    setState(() => _isCleaning = true);

    // 1. طلب الصلاحية
    var status = await Permission.manageExternalStorage.request();
    
    if (status.isGranted) {
      try {
        // 2. تحديد مسار الـ Thumbnails (المسار الشائع في الأندرويد)
        Directory thumbDir = Directory('/storage/emulated/0/DCIM/.thumbnails');
        
        if (await thumbDir.exists()) {
          List<FileSystemEntity> files = thumbDir.listSync();
          int count = 0;
          
          for (var file in files) {
            if (file is File) {
              await file.delete();
              count++;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف $count ملف مؤقت بنجاح!')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على مجلد الـ Thumbnails')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء المسح: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى منح صلاحية الوصول للملفات')));
    }
    
    setState(() => _isCleaning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaner App')),
      body: Center(
        child: _isCleaning 
          ? const CircularProgressIndicator() 
          : ElevatedButton(
              onPressed: () => _cleanThumbnails(context),
              child: const Text('بدء عملية التنظيف'),
            ),
    );
  }
}
