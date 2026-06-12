import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const Color _lightPrimary = Color(0xFF0F172A); // Slate 900
  static const Color _lightSecondary = Color(0xFF475569); // Slate 600
  static const Color _lightMuted = Color(0xFF64748B); // Slate 500

  static Color _textPrimary(bool isDark) => isDark ? AppColors.textPrimary : _lightPrimary;
  static Color _textSecondary(bool isDark) => isDark ? AppColors.textSecondary : _lightSecondary;
  static Color _textMuted(bool isDark) => isDark ? AppColors.textMuted : _lightMuted;

  static TextStyle display(bool isDark) => TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: _textPrimary(isDark),
        letterSpacing: -1.0,
        height: 1.15,
      );

  static TextStyle title1(bool isDark) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: _textPrimary(isDark),
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle title2(bool isDark) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _textPrimary(isDark),
        letterSpacing: -0.4,
        height: 1.25,
      );

  static TextStyle title3(bool isDark) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        letterSpacing: -0.2,
        height: 1.3,
      );

  static TextStyle body(bool isDark) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _textPrimary(isDark),
        height: 1.45,
      );

  static TextStyle label(bool isDark) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        height: 1.3,
      );

  static TextStyle caption(bool isDark) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _textSecondary(isDark),
        height: 1.35,
      );

  static TextStyle small(bool isDark) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _textMuted(isDark),
        height: 1.3,
      );

  static TextStyle statValue(bool isDark) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: _textPrimary(isDark),
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle statLabel(bool isDark) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _textSecondary(isDark),
        height: 1.3,
      );

  static TextStyle badge(bool isDark) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textPrimary(isDark),
        letterSpacing: 0.5,
        height: 1.2,
      );

  static TextStyle button(bool isDark) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        height: 1.2,
      );

  static TextStyle greeting(bool isDark) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textSecondary(isDark),
        height: 1.3,
      );
}
