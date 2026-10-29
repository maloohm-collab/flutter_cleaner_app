import 'package:flutter/material.dart';
import '../services/cleaner_engine.dart';
import '../utils/colors.dart';

class CleanupResultScreen extends StatelessWidget {
  final int deletedFiles;
  final int freedBytes;
  final int selectedBytes;
  const CleanupResultScreen({super.key, required this.deletedFiles, required this.freedBytes, required this.selectedBytes});
  bool get _hasDeletions => deletedFiles > 0;
  @override
  Widget build(BuildContext context) {
    final Color accent = _hasDeletions ? AppColors.success : AppColors.warning;
    return Scaffold(backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.textPrimary, elevation: 0, automaticallyImplyLeading: false, centerTitle: true, title: const Text('نتيجة التنظيف', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: ListView(children: [
          const SizedBox(height: 12),
          Center(child: Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withAlpha(32), border: Border.all(color: accent, width: 2)), child: Icon(_hasDeletions ? Icons.check_rounded : Icons.info_outline_rounded, color: accent, size: 56))),
          const SizedBox(height: 18),
          Text(_hasDeletions ? 'اكتمل التنظيف' : 'لم يُحذف أي ملف', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _ResultStat(label: 'المساحة المحرَّرة', value: CleanerEngine.formatBytes(freedBytes), color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _ResultStat(label: 'الملفات المحذوفة', value: '$deletedFiles', color: AppColors.success)),
          ]),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Text(_hasDeletions
            ? 'الأرقام أعلاه تخص الملفات التي أكّد التطبيق حذفها فقط. كان الحجم الذي حددته قبل الحذف تقريبًا ${CleanerEngine.formatBytes(selectedBytes)}، وقد يقل الرقم الفعلي إذا تعذر حذف بعض الملفات أو اختفت قبل التنفيذ.'
            : 'قد تكون الملفات المحددة قد حُذفت أو نُقلت قبل التنفيذ، أو منع النظام حذفها. أعد الفحص للتحقق مما تبقى.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.55))),
        ])),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.radar_rounded), label: const Text('إعادة الفحص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(context).pop(false), style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary), child: const Text('تم', style: TextStyle(fontSize: 16))),
      ]))),
    );
  }
}
class _ResultStat extends StatelessWidget {
  final String label; final String value; final Color color;
  const _ResultStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(children: [
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
  ]));
}
