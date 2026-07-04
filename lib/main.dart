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
    // يمكنك تغيير "Maloohm123" لأي كود تريده لكل مستخدم
    if (_codeController.text == "Maloohm123") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainCleanerScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كود التفعيل غير صحيح! يرجى التواصل مع الدعم.')),
      );
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
            const Text('يرجى إدخال كود التشغيل للبدء:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'كود التفعيل',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkActivation,
              child: const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}

// الشاشة الرئيسية بعد التفعيل
class MainCleanerScreen extends StatelessWidget {
  const MainCleanerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaner App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cleaning_services, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // هنا سيتم إضافة منطق مسح الملفات لاحقاً
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري فحص وحذف الملفات المؤقتة...')),
                );
              },
              child: const Text('بدء عملية التنظيف'),
            ),
          ],
        ),
      ),
    );
  }
}
