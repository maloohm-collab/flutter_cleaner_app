import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';

class CategoryDetailsScreen extends StatefulWidget {
  final String title;
  final List<File> files;
  final String Function(int) formatBytes;
  final bool canSelectForDeletion;
  final List<String> initialSelectedPaths;
  final ValueChanged<List<String>> onSelectFiles;
  const CategoryDetailsScreen({super.key, required this.title, required this.files, required this.formatBytes, required this.canSelectForDeletion, this.initialSelectedPaths = const <String>[], required this.onSelectFiles});
  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}
class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  final Set<String> _selectedPaths = <String>{};
  @override
  void initState() { super.initState(); _selectedPaths.addAll(widget.initialSelectedPaths); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.card, foregroundColor: AppColors.textPrimary, elevation: 0, title: const Text('مراجعة الملفات', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
    body: SafeArea(child: Column(children: [
      Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${widget.files.length} ملف مكتشف • ${_selectedPaths.length} محدد', style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('راجع اسم كل ملف ومساره وحجمه، وحدد الملفات التي تريد حذفها فقط. لن يُحذف شيء قبل تأكيد العملية في الشاشة التالية.', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5)),
      ])),
      Expanded(child: widget.files.isEmpty ? const Center(child: Text('لا توجد ملفات متاحة للعرض.', style: TextStyle(color: AppColors.textSecondary, fontSize: 17))) : ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), itemCount: widget.files.length, separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final file = widget.files[index]; final selected = _selectedPaths.contains(file.path);
          return FutureBuilder<int>(future: file.length(), builder: (context, snapshot) {
            final size = snapshot.hasError ? 'الحجم غير متاح' : snapshot.hasData ? widget.formatBytes(snapshot.data!) : 'جارٍ حساب الحجم…';
            return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: selected, activeColor: AppColors.primary, onChanged: widget.canSelectForDeletion ? (value) => setState(() { if (value == true) { _selectedPaths.add(file.path); } else { _selectedPaths.remove(file.path); } }) : null),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6), Text('الحجم: $size', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7), SelectableText(file.path, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45)),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: file.path)), icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('نسخ المسار'))),
              ])),
            ]));
          });
        })),
      if (widget.canSelectForDeletion) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 18), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _selectedPaths.isEmpty ? null : () => widget.onSelectFiles(_selectedPaths.toList()),
        icon: const Icon(Icons.check_circle_outline_rounded), label: Text('اعتماد ${_selectedPaths.length} ملف محدد', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.background, disabledBackgroundColor: AppColors.border, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ))),
    ])),
  );
}
