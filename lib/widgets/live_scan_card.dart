import 'package:flutter/material.dart';
import '../utils/colors.dart';

class LiveScanCard extends StatelessWidget {
  final String currentTask;
  final double progress;
  final bool scanning;

  const LiveScanCard({
    super.key,
    required this.currentTask,
    required this.progress,
    required this.scanning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              Icon(
                scanning ? Icons.radar : Icons.check_circle,
                color: scanning
                    ? AppColors.primary
                    : AppColors.success,
              ),

              const SizedBox(width: 10),

              Text(
                scanning ? "LIVE AI SCAN" : "SYSTEM STATUS",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

            ],
          ),

          const SizedBox(height: 18),

          Text(
            currentTask,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        ],
      ),
    );
  }
}
