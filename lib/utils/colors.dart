import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFEDF3FA);

  static const Color card = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF087F9B);

  static const Color secondary = Color(0xFF5267B8);

  static const Color success = Color(0xFF2EE59D);

  static const Color warning = Color(0xFFFFC857);

  static const Color danger = Color(0xFFFF5C7A);

  static const Color textPrimary = Color(0xFF172A45);

  static const Color textSecondary = Color(0xFF34445B);

  static const Color field = Color(0xFFE4EBF4);

  static const Color border = Color(0xFFCFDCE9);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF00D2FF),
      Color(0xFF7B61FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFF0099FF),
      Color(0xFF8A4DFF),
    ],
  );
}
