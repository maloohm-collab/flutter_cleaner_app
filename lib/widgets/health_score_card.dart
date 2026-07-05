import 'package:flutter/material.dart';
import '../utils/colors.dart';

class HealthScoreCard extends StatelessWidget {
  final double score;
  final String status;

  const HealthScoreCard({
    super.key,
    required this.score,
    required this.status,
  });

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

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              status,
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
