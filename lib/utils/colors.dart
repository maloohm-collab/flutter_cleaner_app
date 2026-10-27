import 'package:flutter/material.dart';

/// AI Optimizer — restored dark navy palette with strong readable contrast.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF090D1A);
  static const Color card = Color(0xFF17243A);
  static const Color primary = Color(0xFF00C7E8);
  static const Color secondary = Color(0xFF6478FF);
  static const Color success = Color(0xFF39D98A);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF647C);
  static const Color textPrimary = Color(0xFFF7FAFF);
  static const Color textSecondary = Color(0xFFC3D0E2);
  static const Color field = Color(0xFF101A2C);
  static const Color border = Color(0xFF354963);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00AFC8), Color(0xFF6657F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF00AFC8), Color(0xFF6657F5)],
  );
}
