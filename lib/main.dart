import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const CleanerApp());

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, 
    theme: ThemeData.dark(),
    home: const MainCleanerScreen()
  );
}

class MainCleanerScreen extends StatefulWidget {
  const MainCleanerScreen({super.key});
  @override
  State<MainCleanerScreen> createState() => _MainCleanerScreenState();
}

class _MainCleanerScreenState extends State<MainCleanerScreen> {
  List<File> _junkFiles = [];
  bool _isScanning = false;

  // دالة البحث الذكي عن مجلدات thumbnails
  Future<void> _scanSystem() async {
    setState(() => _isScanning = true);
    var status = await Permission.manageExternalStorage.request();
    
    if (status.isGranted) {
      List<File> foundFiles = [];
      // البحث في وحدة التخزين الرئيسية
      Directory root = Directory('/storage/emulated/0/');
      
      // دالة استكشاف المجلدات بشكل متكرر (Recursive)
      void findThumbnails(Directory dir) {
        try {
          List<FileSystemEntity> entities = dir.listSync();
          for (var entity in entities) {
            if (entity is Directory) {
              if (entity.path.split('/').last.toLowerCase().contains('thumbnails')) {
                foundFiles.addAll(entity.listSync().whereType<File>());
              } else {
                findThumbnails(entity); // البحث في المجلدات الفرعية
              }
            }
          }
        } catch (e) { /* تجاهل المجلدات المحمية */ }
      }
      
      findThumbnails(root);
      setState(() => _junkFiles = foundFiles);
    }
    setState(() => _isScanning = false);
  }

  // حذف ملف واحد
  Future<void> _deleteFile(File file) async {
    await file.delete();
    setState(() => _junkFiles.remove(file));
  }

  // حذف الكل
  void _deleteAll() {
    for (var file in _junkFiles) { file.delete(); }
    setState(() => _junkFiles.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI SCANNER")),
      body: _isScanning 
        ? const Center(child: CircularProgressIndicator())
        : _junkFiles.isEmpty
          ? Center(child: ElevatedButton(onPressed: _scanFiles, child: const Text("ابدأ الفحص الشامل")))
          : Column(
              children: [
                ElevatedButton(onPressed: _deleteAll, child: const Text("حذف الكل (Bulk Delete)")),
                Expanded(
                  child: ListView.builder(
                    itemCount: _junkFiles.length,
                    itemBuilder: (context, index) {
                      final file = _junkFiles[index];
                      return ListTile(
                        title: Text(file.path.split('/').last),
                        subtitle: Text(file.path, style: const TextStyle(fontSize: 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(file),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmDelete(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل تريد إزالة هذا الملف؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(onPressed: () { _deleteFile(file); Navigator.pop(context); }, child: const Text("حذف")),
        ],
      ),
    );
  }
}

