import 'package:flutter_cleaner_app/services/scan_item.dart'; // 👈 أضف هذا السطر في أول الملف
import 'package:flutter/material.dart';

// بقية كود الـ Widget الخاص بك بدون أي تغيير...

import '../utils/colors.dart';

class ScanResultCard extends StatelessWidget {
  final ScanItem item;
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
        onChanged: onChanged,
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
          "${item.files} files\n${item.readableSize}",
        ),
      ),
    );
  }
}
