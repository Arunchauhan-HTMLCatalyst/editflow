import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF18181B),
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          error: AppColors.error,
          outline: const Color(0xFFE4E4E7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FA),
        appBarTheme: _appBarTheme(Brightness.light),
        cardTheme: _cardTheme(Brightness.light),
        inputDecorationTheme: _inputTheme(Brightness.light),
        elevatedButtonTheme: _elevatedButtonTheme(),
        outlinedButtonTheme: _outlinedButtonTheme(Brightness.light),
        textButtonTheme: _textButtonTheme(),
        dividerTheme: _dividerTheme(Brightness.light),
        snackBarTheme: _snackBarTheme(Brightness.light),
        dialogTheme: _dialogTheme(Brightness.light),
        checkboxTheme: _checkboxTheme(AppColors.border),
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
    final borderColor = isDark ? AppColors.border : const Color(0xFFE4E4E7);
    final surfaceColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8F8FA);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        surface: surfaceColor,
        onSurface: isDark ? AppColors.textPrimary : const Color(0xFF18181B),
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.primary,
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
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8F8FA),
      foregroundColor: isDark ? AppColors.textPrimary : const Color(0xFF18181B),
      titleSpacing: 0,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  static CardThemeData _cardTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.card : const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.none,
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : const Color(0xFFF1F1F3);
    return InputDecorationTheme(
      filled: true,
      fillColor: bgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(color: AppColors.borderFocused, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.textMuted : const Color(0xFF71717A),
      ),
      hintStyle: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.textMuted : const Color(0xFF71717A),
      ),
      prefixIconColor: isDark ? AppColors.textMuted : const Color(0xFF71717A),
      suffixIconColor: isDark ? AppColors.textMuted : const Color(0xFF71717A),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.textPrimary : const Color(0xFF18181B),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE4E4E7),
          width: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }

  static DividerThemeData _dividerTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DividerThemeData(
      color: isDark ? AppColors.border : const Color(0xFFE4E4E7),
      thickness: 0.5,
      space: 0,
    );
  }

  static SnackBarThemeData _snackBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.elevated : const Color(0xFF18181B),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE4E4E7),
          width: 0.5,
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
        borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  static CheckboxThemeData _checkboxTheme(Color borderColor) {
    return CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      side: BorderSide(color: borderColor, width: 1),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.dialogRadius)),
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
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: isDark ? AppColors.border : const Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    );
  }
}
