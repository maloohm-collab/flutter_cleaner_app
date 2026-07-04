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

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();

  void _checkActivation() {
    // هنا تضع كود التفعيل الذي تريده
    if (_codeController.text == "Maloohm123") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainCleanerScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود التفعيل غير صحيح!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل التطبيق')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'أدخل كود التفعيل')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _checkActivation, child: const Text('تفعيل')),
          ],
        ),
      ),
    );
  }
}

class MainCleanerScreen extends StatelessWidget {
  const MainCleanerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaner App - تنظيف')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // هنا سنضع لاحقاً كود مسح الملفات
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تنظيف الملفات المؤقتة...')));
          },
          child: const Text('بدء التنظيف الآن'),
        ),
      ),
    );
  }
}
