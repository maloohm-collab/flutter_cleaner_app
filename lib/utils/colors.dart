import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF182238);

  static const Color card = Color(0xFF25334D);

  static const Color primary = Color(0xFF00D2FF);

  static const Color secondary = Color(0xFF7B61FF);

  static const Color success = Color(0xFF2EE59D);

  static const Color warning = Color(0xFFFFC857);

  static const Color danger = Color(0xFFFF5C7A);

  static const Color textPrimary = Colors.white;

  static const Color textSecondary = Color(0xFFE0E7F2);

  static const Color field = Color(0xFF33425D);

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
