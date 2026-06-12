import 'package:flutter/material.dart';

class AppLayout {
  AppLayout._();

  // Breakpoints
  static const double mobile = 600;
  static const double tablet = 900;

  /// Returns true for screens >= 600px
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobile;

  /// Returns true for screens >= 900px
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;

  /// Returns the number of columns for a responsive grid
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tablet) return 3;
    if (width >= mobile) return 2;
    return 1;
  }

  /// Adaptive horizontal page padding
  static double pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tablet) return 32;
    if (width >= mobile) return 24;
    return 16;
  }

  /// Maximum content width for large screens (centered)
  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 1200 ? 1200 : width;
  }

  /// Gap between grid items
  static double get gridGap => 12;

  /// Returns the cross-axis count for a responsive grid
  static SliverGridDelegateWithFixedCrossAxisCount gridDelegate(
      BuildContext context, double childAspectRatio) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: gridColumns(context),
      mainAxisSpacing: gridGap,
      crossAxisSpacing: gridGap,
      childAspectRatio: childAspectRatio,
    );
  }
}
