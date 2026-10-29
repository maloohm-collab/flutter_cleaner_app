import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';

class FilePathDetailsScreen extends StatelessWidget {
  final String path; final int bytes; final String Function(int) formatBytes;
  const FilePathDetailsScreen({super.key, required this.path, required this.bytes, required this.formatBytes});
  String get _fileName { final parts = path.split('/'); return parts.isEmpty || parts.last.isEmpty ? path : parts.last; }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.card, foregroundColor: AppColors.textPrimary, elevation: 0, title: const Text('تفاصيل الملف', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary, size: 42), const SizedBox(height: 14),
        Text(_fileName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14), const Text('الحجم المرصود', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        Text(formatBytes(bytes), style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18), const Text('المسار الكامل', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7), SelectableText(path, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
        const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: path)), icon: const Icon(Icons.copy_rounded), label: const Text('نسخ مسار الملف', style: TextStyle(fontSize: 16)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.border)))),
        const SizedBox(height: 8), const Text('لم يتم فتح الملف أو حذفه. هذه صفحة معلومات لمساعدتك على الوصول إليه يدويًا عبر مدير الملفات.', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5)),
      ])),
    ]),
  );
}
