import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0E21);

  static const Color card = Color(0xFF151A30);

  static const Color primary = Color(0xFF00D2FF);

  static const Color secondary = Color(0xFF7B61FF);

  static const Color success = Color(0xFF2EE59D);

  static const Color warning = Color(0xFFFFC857);

  static const Color danger = Color(0xFFFF5C7A);

  static const Color textPrimary = Colors.white;

  static const Color textSecondary = Colors.white70;

  static const Color field = Color(0xFF232840);

  static const Color border = Color(0x332EDBFF);

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
