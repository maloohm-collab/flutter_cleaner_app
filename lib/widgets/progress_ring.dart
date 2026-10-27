
import 'package:flutter/material.dart';
import '../utils/colors.dart';

class ProgressRing extends StatelessWidget {
  final double progress;
  final String title;
  final String subtitle;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 12,
              backgroundColor: const Color(0xFFD5DFEA),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${(value * 100).toInt()}%",
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
