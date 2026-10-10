// ============================================================
// Project      : AI Cleaner
// File         : lib/widgets/scan_result_card.dart
// Version      : 1.1.0
// Last Updated : 2026-10-10
// Purpose      : عرض نتيجة فحص واحدة مع إمكانية تحديدها للتنظيف.
//
// Changes:
// - توثيق الملف وإضافة بيانات الإصدار.
// - الحفاظ على تصميم البطاقة الحالي.
// - ربط مربع الاختيار بحالة ScanItem.selected.
// - تمرير تغيير التحديد إلى العنصر الأب عبر onChanged.
//
// Safety Notes:
// - هذا Widget للعرض وتغيير التحديد فقط.
// - لا يحذف الملفات بنفسه.
// - أمان الحذف يجب التحقق منه داخل محرك التنظيف.
//
// Dependencies:
// - Flutter Material.
// - lib/services/scan_item.dart
// - lib/utils/colors.dart
//
// Compatibility:
// - يعتمد على ScanItem وخصائصه الحالية.
// - متوافق مع واجهة CheckboxListTile في Flutter.
//
// Validation:
// - تمت مراجعة الكود منطقيًا.
// - لم يتم إجراء Flutter build أو اختبارات تشغيلية.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';

import '../utils/colors.dart';

/// بطاقة تعرض فئة من الملفات المكتشفة أثناء الفحص.
class ScanResultCard extends StatelessWidget {
  /// بيانات العنصر المعروض.
  final ScanItem item;

  /// يستقبل حالة التحديد الجديدة من مربع الاختيار.
  final ValueChanged<bool?> onChanged;

  const ScanResultCard({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: CheckboxListTile(
        value: item.selected,
        onChanged: item.safeToDelete ? onChanged : null,
        activeColor: AppColors.primary,
        secondary: const Icon(
          Icons.auto_delete,
          color: AppColors.primary,
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${item.files} files\n${item.readableSize}',
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
      ),
    );
  }
}
