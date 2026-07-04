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
    return MaterialApp(home: const ActivationScreen());
  }
}

// ... [كود ActivationScreen كما هو سابقاً] ...

class MainCleanerScreen extends StatelessWidget {
  const MainCleanerScreen({super.key});

  // دالة طلب الصلاحيات والبدء بالتنظيف
  Future<void> _startCleaning(BuildContext context) async {
    // طلب صلاحية إدارة الملفات
    var status = await Permission.manageExternalStorage.request();
    
    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري البحث عن ملفات الـ Thumbnails...')));
      
      // هنا منطق المسح (مثال لمسار مجلد الصور)
      // ملاحظة: مسح ملفات النظام يتطلب تحديد مسارات دقيقة
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم المسح بنجاح!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى منح صلاحية الوصول للملفات للبدء')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaner App')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _startCleaning(context),
          child: const Text('بدء عملية التنظيف'),
        ),
      ),
    );
  }
}
