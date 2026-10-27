import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFEDF3FA);

  static const Color card = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF075E75);

  static const Color secondary = Color(0xFF384D91);

  static const Color success = Color(0xFF16734A);

  static const Color warning = Color(0xFF8A5700);

  static const Color danger = Color(0xFFB4233A);

  static const Color textPrimary = Color(0xFF172A45);

  static const Color textSecondary = Color(0xFF34445B);

  static const Color field = Color(0xFFF5F8FC);

  static const Color border = Color(0xFFB9C8D9);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF087F9B),
      Color(0xFF4656B5),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFF087F9B),
      Color(0xFF4656B5),
    ],
  );
}
