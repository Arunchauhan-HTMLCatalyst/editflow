import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background — true dark
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF111113);
  static const Color card = Color(0xFF18181B);
  static const Color elevated = Color(0xFF1C1C1F);

  // Borders
  static const Color border = Color(0xFF27272A);
  static const Color borderFocused = Color(0xFF3F3F46);

  // Accent
  static const Color primary = Color(0xFF8B5CF6);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFFA78BFA);

  // Text
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Chart
  static const Color chartLine = Color(0xFF8B5CF6);
  static const Color chartArea = Color(0x1A8B5CF6);

  // Overlay
  static const Color overlay = Color(0x0AFFFFFF);
  static const Color overlayHover = Color(0x14FFFFFF);

  // Status badge colors (keep minimal — only semantic tints)
  static Color statusBg(Color c) => c.withValues(alpha: 0.1);
  static Color statusText(Color c) => c;
}
