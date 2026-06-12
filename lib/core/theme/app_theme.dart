import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF0F172A), // Slate 900
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          error: AppColors.error,
          outline: const Color(0xFFE2E8F0), // Slate 200
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: _appBarTheme(Brightness.light),
        cardTheme: _cardTheme(Brightness.light),
        inputDecorationTheme: _inputTheme(Brightness.light),
        elevatedButtonTheme: _elevatedButtonTheme(),
        outlinedButtonTheme: _outlinedButtonTheme(Brightness.light),
        textButtonTheme: _textButtonTheme(),
        dividerTheme: _dividerTheme(Brightness.light),
        snackBarTheme: _snackBarTheme(Brightness.light),
        dialogTheme: _dialogTheme(Brightness.light),
        checkboxTheme: _checkboxTheme(const Color(0xFFCBD5E1)),
        bottomSheetTheme: _bottomSheetTheme(Brightness.light),
        popupMenuTheme: _popupMenuTheme(Brightness.light),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.primary.withValues(alpha: 0.3),
          selectionHandleColor: AppColors.primary,
        ),
      );

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final surfaceColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8FAFC);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        surface: surfaceColor,
        onSurface: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.primaryNeon,
        onSecondary: AppColors.onPrimary,
        error: AppColors.error,
        onError: AppColors.onPrimary,
        outline: borderColor,
      ),
      scaffoldBackgroundColor: bgColor,
      appBarTheme: _appBarTheme(brightness),
      cardTheme: _cardTheme(brightness),
      inputDecorationTheme: _inputTheme(brightness),
      elevatedButtonTheme: _elevatedButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(brightness),
      textButtonTheme: _textButtonTheme(),
      dividerTheme: _dividerTheme(brightness),
      snackBarTheme: _snackBarTheme(brightness),
      dialogTheme: _dialogTheme(brightness),
      checkboxTheme: _checkboxTheme(borderColor),
      bottomSheetTheme: _bottomSheetTheme(brightness),
      popupMenuTheme: _popupMenuTheme(brightness),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }

  static AppBarTheme _appBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppColors.background : Colors.transparent,
      foregroundColor: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
      titleSpacing: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  static CardThemeData _cardTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return CardThemeData(
      elevation: isDark ? 0 : 2.0,
      color: isDark ? AppColors.card : const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shadowColor: isDark ? Colors.transparent : const Color(0x060F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // Upgraded to premium 16.0
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.none,
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark ? AppColors.border : const Color(0xFFE2E8F0);
    return InputDecorationTheme(
      filled: true,
      fillColor: bgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: isDark ? borderColor : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.borderFocused, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
      ),
      hintStyle: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
      ),
      prefixIconColor: isDark ? AppColors.textMuted : const Color(0xFF64748B),
      suffixIconColor: isDark ? AppColors.textMuted : const Color(0xFF64748B),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // Clean rounded corners
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.2,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  static DividerThemeData _dividerTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DividerThemeData(
      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
      thickness: 0.8,
      space: 0,
    );
  }

  static SnackBarThemeData _snackBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.elevated : const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      actionTextColor: AppColors.primary,
    );
  }

  static DialogThemeData _dialogTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DialogThemeData(
      backgroundColor: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  static CheckboxThemeData _checkboxTheme(Color borderColor) {
    return CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      side: BorderSide(color: borderColor, width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.onPrimary),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      modalBarrierColor: isDark ? const Color(0x80000000) : const Color(0x40000000),
    );
  }

  static PopupMenuThemeData _popupMenuTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return PopupMenuThemeData(
      color: isDark ? AppColors.elevated : const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      textStyle: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
      ),
    );
  }
}
