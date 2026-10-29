import 'package:flutter/material.dart';
import '../utils/colors.dart';

class LargestFilesScreen extends StatelessWidget {
  final List<MapEntry<String, int>> files;
  final String Function(int) formatBytes;
  final void Function(String, int) onOpenFile;
  const LargestFilesScreen({super.key, required this.files, required this.formatBytes, required this.onOpenFile});
  String _nameOf(String path) { final parts = path.split('/'); return parts.isEmpty || parts.last.isEmpty ? path : parts.last; }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.card, foregroundColor: AppColors.textPrimary, elevation: 0, title: const Text('أكبر الملفات المكتشفة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(margin: const EdgeInsets.fromLTRB(16, 12, 16, 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: const Text('هذه الملفات مرتبة حسب الحجم. اضغط على أي ملف لعرض اسمه الكامل ومساره وحجمه. هذه الشاشة لا تحذف الملفات.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5, fontWeight: FontWeight.w600))),
      Expanded(child: files.isEmpty ? const Center(child: Text('لا توجد ملفات لعرضها. أعد الفحص أولًا.', style: TextStyle(color: AppColors.textSecondary, fontSize: 17))) : ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), itemCount: files.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) { final entry = files[index]; return Material(color: AppColors.card, borderRadius: BorderRadius.circular(14), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => onOpenFile(entry.key, entry.value), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary, size: 30), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_nameOf(entry.key), style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6), Text(entry.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
            const SizedBox(height: 7), Text('الحجم: ${formatBytes(entry.value)}', style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800)),
          ])), const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 28),
        ]))); },
      )),
    ]),
  );
}
