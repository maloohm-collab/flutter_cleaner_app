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
        color: const Color(0xFF243650),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6E8AAE), width: 1.2),
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
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              item.safeToDelete
                  ? '${item.files} ملف مكتشف\n${item.readableSize}\nيمكنك مراجعة المسارات قبل الحذف.'
                  : '${item.files} ملف مكتشف\n${item.readableSize}\nللعرض فقط؛ لا يمكن حذف هذه الفئة من التطبيق.',
              style: const TextStyle(
                color: const Color(0xFFE2EAF5),
                fontSize: 15,
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
                  'إظهار تفاصيل الملفات والمسارات قبل الحذف',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDAF5FF),
                  foregroundColor: const Color(0xFF12344A),
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
