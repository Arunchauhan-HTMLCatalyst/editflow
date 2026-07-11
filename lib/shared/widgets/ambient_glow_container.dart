import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AmbientGlowContainer extends StatelessWidget {
  final Widget child;
  final bool showBottomGlow;
  final Color? topGlowColor;
  final Color? bottomGlowColor;

  const AmbientGlowContainer({
    super.key,
    required this.child,
    this.showBottomGlow = true,
    this.topGlowColor,
    this.bottomGlowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!isDark) {
      return Container(
        color: Colors.white,
        child: child,
      );
    }

    final topColor = topGlowColor ?? AppColors.primary;
    final bottomColor = bottomGlowColor ?? AppColors.primaryNeon;

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Top-Right Soft Teal Glow
          Positioned(
            right: -100,
            top: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    topColor.withValues(alpha: 0.12),
                    topColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Bottom-Left Soft Cyan/Emerald Glow
          if (showBottomGlow)
            Positioned(
              left: -120,
              bottom: -120,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      bottomColor.withValues(alpha: 0.08),
                      bottomColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          // Content
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
