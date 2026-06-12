import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF080C0D); // Deep charcoal-black
  static const Color surface = Color(0xFF101517);
  static const Color card = Color(0xFF171D1F); // Dark slate/charcoal glassmorphic background
  static const Color elevated = Color(0xFF1F2629);

  // Borders
  static const Color border = Color(0xFF273135);
  static const Color borderFocused = Color(0xFF0D9488); // Teal

  // Accents - Premium Teal & Emerald Mint
  static const Color primary = Color(0xFF0D9488); // Teal
  static const Color primaryNeon = Color(0xFF10B981); // Emerald Mint
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFF43F5E); // Rose Red
  static const Color info = Color(0xFF0EA5E9); // Sky Blue

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate-like white
  static const Color textSecondary = Color(0xFF94A3B8); // Slate-like gray
  static const Color textMuted = Color(0xFF64748B); // Slate-like muted

  // Chart Colors
  static const Color chartLine = Color(0xFF0D9488);
  static const Color chartArea = Color(0x1F0D9488);

  // Overlays
  static const Color overlay = Color(0x0DFFFFFF);
  static const Color overlayHover = Color(0x1AFFFFFF);

  // Gradients for UI Elements
  static const List<Color> primaryGradient = [
    Color(0xFF0D9488), // Teal
    Color(0xFF10B981), // Emerald
  ];

  static const List<Color> accentGradient = [
    Color(0xFF06B6D4), // Cyan
    Color(0xFF0D9488), // Teal
  ];

  static const List<Color> successGradient = [
    Color(0xFF10B981),
    Color(0xFF059669),
  ];

  static const List<Color> bgDarkGradient = [
    Color(0xFF07070C),
    Color(0xFF0F0F1A),
  ];

  static const List<Color> bgLightGradient = [
    Color(0xFFE0F7F4), // Soft Teal-Mint (matches logo)
    Color(0xFFF4FDFB), // Soft Teal-White
    Color(0xFFFFFFFF), // Pure White
  ];

  // Status badge colors
  static Color statusBg(Color c) => c.withValues(alpha: 0.12);
  static Color statusText(Color c) => c;
}
