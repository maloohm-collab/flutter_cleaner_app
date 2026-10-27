// Result card: explicit inspection before user-confirmed cleanup.
import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';
import '../utils/colors.dart';

class ScanResultCard extends StatelessWidget {
  final ScanItem item;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onDetails;

  const ScanResultCard({
    super.key,
    required this.item,
    required this.onChanged,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: item.selected,
            onChanged: item.safeToDelete ? onChanged : null,
            activeColor: AppColors.primary,
            secondary: Icon(
              item.id == 'thumbnail_files'
                  ? Icons.photo_size_select_small_outlined
                  : Icons.folder_open_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              item.safeToDelete
                  ? '${item.files} ملف مكتشف\n${item.readableSize}\nيمكنك مراجعة المسارات قبل الحذف.'
                  : '${item.files} ملف مكتشف\n${item.readableSize}\nللعرض فقط؛ لا يمكن حذف هذه الفئة من التطبيق.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            isThreeLine: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDetails,
                icon: const Icon(Icons.visibility_outlined, size: 21),
                label: const Text(
                  'عرض التفاصيل والمسارات قبل الحذف',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.field,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
