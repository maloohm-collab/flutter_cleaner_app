import 'package:flutter/material.dart';
import '../utils/colors.dart';

class HealthScoreCard extends StatelessWidget {
  final double score;
  final String? status; // إضافة معامل اختياري لاستقبال الحالة المرسلة

  const HealthScoreCard({
    super.key,
    required this.score,
    this.status, // تعريف المعامل في الكونستركتور
  });

  // دالة ذكية لتحديد حالة الجهاز ديناميكياً
  String _getHealthStatus(double healthScore) {
    if (healthScore >= 85) return "Excellent";
    if (healthScore >= 70) return "Good";
    if (healthScore >= 50) return "Fair";
    return "Action Required";
  }

  // دالة لتغيير لون خلفية الحالة
  Color _getStatusColor(double healthScore) {
    if (healthScore >= 85) return Colors.white24;
    if (healthScore >= 70) return Colors.white12;
    if (healthScore >= 50) return Colors.orange.withOpacity(0.3);
    return Colors.red.withOpacity(0.4);
  }

  @override
  Widget build(BuildContext context) {
    // نستخدم الحالة المرسلة إذا وجدت (status)، وإلا نستخدم الحساب التلقائي (_getHealthStatus)
    final String displayStatus = status ?? _getHealthStatus(score);

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
              displayStatus, // استخدام المتغير الموحد للعرض
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
