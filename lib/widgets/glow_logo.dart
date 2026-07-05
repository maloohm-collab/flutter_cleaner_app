import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/colors.dart';

class GlowLogo extends StatelessWidget {
  final double size;
  final IconData icon;

  const GlowLogo({
    super.key,
    this.size = 120,
    this.icon = Icons.rocket_launch_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 35,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: Colors.white,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.05, 1.05),
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}
