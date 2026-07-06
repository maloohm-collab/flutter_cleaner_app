import 'package:flutter/material.dart';
import '../utils/colors.dart';

class LiveScanCard extends StatefulWidget {
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
  State<LiveScanCard> createState() => _LiveScanCardState();
}

class _LiveScanCardState extends State<LiveScanCard> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    // تهيئة متحكم الدوران الخاص بأيقونة الرادار
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.scanning) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LiveScanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // مراقبة حالة الفحص لبدء أو إيقاف حركة الرادار تلقائياً
    if (widget.scanning) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

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
              // تأثير الدوران الحي لأيقونة الرادار أثناء الفحص
              widget.scanning
                  ? RotationTransition(
                      turns: _rotationController,
                      child: const Icon(
                        Icons.radar,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 26,
                    ),
              const SizedBox(width: 10),
              Text(
                widget.scanning ? "LIVE AI SCAN" : "SYSTEM STATUS",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // نص المهمة الحالية يتغير بسلاسة مع حركة المحرك
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              widget.currentTask,
              key: ValueKey<String>(widget.currentTask),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: widget.progress,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(widget.progress * 100).toInt()}%",
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
