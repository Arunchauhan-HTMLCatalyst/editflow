import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class GoalTracker extends StatelessWidget {
  final double currentRevenue;
  final double goal;
  final String Function(double) formatValue;

  const GoalTracker({
    super.key,
    required this.currentRevenue,
    required this.goal,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (currentRevenue / goal).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: _GoalRingPainter(progress: progress, isDark: isDark),
                child: Center(
                  child: Text(
                    '$percent%',
                    style: AppTextStyles.label(isDark).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Goal',
                    style: AppTextStyles.caption(isDark),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatValue(currentRevenue),
                    style: AppTextStyles.statValue(isDark).copyWith(fontSize: 22),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    'of ${formatValue(goal)}',
                    style: AppTextStyles.small(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _GoalRingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 6;

    final bgPaint = Paint()
      ..color = (isDark ? AppColors.border : Color(0xFFE4E4E7)).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.primary, AppColors.info],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) => old.progress != progress;
}
