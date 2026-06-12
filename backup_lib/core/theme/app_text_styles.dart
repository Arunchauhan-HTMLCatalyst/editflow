import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const Color _lightPrimary = Color(0xFF18181B);
  static const Color _lightSecondary = Color(0xFF52525B);
  static const Color _lightMuted = Color(0xFF71717A);

  static Color _textPrimary(bool isDark) => isDark ? AppColors.textPrimary : _lightPrimary;
  static Color _textSecondary(bool isDark) => isDark ? AppColors.textSecondary : _lightSecondary;
  static Color _textMuted(bool isDark) => isDark ? AppColors.textMuted : _lightMuted;

  static TextStyle display(bool isDark) => TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: _textPrimary(isDark),
        letterSpacing: -0.8,
        height: 1.1,
      );

  static TextStyle title1(bool isDark) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        letterSpacing: -0.4,
        height: 1.2,
      );

  static TextStyle title2(bool isDark) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        letterSpacing: -0.3,
        height: 1.25,
      );

  static TextStyle title3(bool isDark) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        height: 1.3,
      );

  static TextStyle body(bool isDark) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _textPrimary(isDark),
        height: 1.4,
      );

  static TextStyle label(bool isDark) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _textPrimary(isDark),
        height: 1.3,
      );

  static TextStyle caption(bool isDark) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textSecondary(isDark),
        height: 1.3,
      );

  static TextStyle small(bool isDark) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _textMuted(isDark),
        height: 1.3,
      );

  static TextStyle statValue(bool isDark) => TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: _textPrimary(isDark),
        letterSpacing: -0.6,
        height: 1.1,
      );

  static TextStyle statLabel(bool isDark) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textSecondary(isDark),
        height: 1.3,
      );

  static TextStyle badge(bool isDark) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        letterSpacing: 0.3,
        height: 1.2,
      );

  static TextStyle button(bool isDark) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _textPrimary(isDark),
        height: 1.2,
      );

  static TextStyle greeting(bool isDark) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _textSecondary(isDark),
        height: 1.3,
      );
}
