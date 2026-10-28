// Result card: readable contrast and explicit file inspection before cleanup.
import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';
import '../utils/colors.dart';

class ScanResultCard extends StatelessWidget {
  final ScanItem item;
  final VoidCallback? onDetails;

  const ScanResultCard({
    super.key,
    required this.item,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = item.id == 'thumbnail_files'
        ? AppColors.primary
        : AppColors.secondary;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: item.selected ? const Color(0xFF1B3048) : AppColors.card,
      elevation: item.selected ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: item.selected ? AppColors.primary : AppColors.border, width: item.selected ? 1.6 : 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    item.id == 'thumbnail_files'
                        ? Icons.photo_size_select_small_outlined
                        : Icons.folder_open_outlined,
                    color: accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                        style: const TextStyle(
                          color: Color(0xFFF7FAFF),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        )),
                      const SizedBox(height: 5),
                      Text('${item.files} ملف مكتشف • ${item.readableSize}',
                        style: const TextStyle(
                          color: Color(0xFFC3D0E2),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                      const SizedBox(height: 4),
                      Text(
                        item.safeToDelete
                            ? 'راجع أسماء الملفات ومساراتها قبل أن تختار الحذف.'
                            : 'هذه الفئة للعرض فقط ولا يمكن حذفها من التطبيق.',
                        style: const TextStyle(
                          color: Color(0xFFC3D0E2),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.manage_search_rounded, size: 23),
              label: const Text(
                'إظهار تفاصيل الملفات التي تريد حذفها',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent, width: 1.4),
                backgroundColor: const Color(0xFF101A2C),
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (item.safeToDelete) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101A2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'الملفات المحددة يدويًا: ${item.selectedPaths.length} من ${item.files}. افتح التفاصيل لاختيار كل ملف على حدة.',
                  style: const TextStyle(
                    color: Color(0xFFC3D0E2),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
