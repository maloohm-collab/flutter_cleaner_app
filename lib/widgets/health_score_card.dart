import 'package:flutter/material.dart';
import '../utils/colors.dart';

class HealthScoreCard extends StatelessWidget {
  final double score;

  const HealthScoreCard({
    super.key,
    required this.score,
  });

  // دالة ذكية لتحديد حالة الجهاز ديناميكياً ولحظياً بناءً على النتيجة
  String _getHealthStatus(double healthScore) {
    if (healthScore >= 85) return "Excellent";
    if (healthScore >= 70) return "Good";
    if (healthScore >= 50) return "Fair";
    return "Action Required";
  }

  // دالة لتغيير لون خلفية الحالة حسب خطورة الوضع
  Color _getStatusColor(double healthScore) {
    if (healthScore >= 85) return Colors.white24;
    if (healthScore >= 70) return Colors.white12;
    if (healthScore >= 50) return Colors.orange.withOpacity(0.3);
    return Colors.red.withOpacity(0.4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.35),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "AI HEALTH SCORE",
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 2,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "${score.toStringAsFixed(0)}%",
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(score),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              _getHealthStatus(score),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
