import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final int animationDelay;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.animationDelay = 0,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  (double, String, String) _parseNumericValue(String text) {
    final sanitized = text.replaceAll(',', '');
    final numericRegex = RegExp(r'[0-9]+(?:\.[0-9]+)?');
    final match = numericRegex.firstMatch(sanitized);
    if (match == null) {
      return (0.0, '', text);
    }
    final numericStr = match.group(0)!;
    final val = double.tryParse(numericStr) ?? 0.0;

    final origMatch = RegExp(r'[0-9]+[\d,.]*').firstMatch(text);
    if (origMatch == null) {
      return (val, '', text);
    }
    final prefix = text.substring(0, origMatch.start);
    final suffix = text.substring(origMatch.end);
    return (val, prefix, suffix);
  }

  String _formatValue(double val, double targetVal, String prefix, String suffix, bool hasComma, bool isDecimal) {
    if (targetVal == 0.0) return widget.value;
    String formatted = isDecimal ? val.toStringAsFixed(1) : val.round().toString();
    if (hasComma) {
      final parts = formatted.split('.');
      final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
      parts[0] = parts[0].replaceAll(regex, ',');
      formatted = parts.join('.');
    }
    return '$prefix$formatted$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.iconColor ?? AppColors.primary;

    final parsed = _parseNumericValue(widget.value);
    final targetVal = parsed.$1;
    final prefix = parsed.$2;
    final suffix = parsed.$3;
    final hasComma = widget.value.contains(',');
    final isDecimal = widget.value.contains('.');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isDark ? AppColors.card : Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: _isHovered
                      ? color.withValues(alpha: 0.45)
                      : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
                  width: _isHovered ? 1.2 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? color.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.015),
                    blurRadius: _isHovered ? 12 : 4,
                    offset: _isHovered ? const Offset(0, 6) : const Offset(0, 2),
                  )
                ],
              ),
              transform: _isHovered
                  ? (Matrix4.translationValues(0.0, -3.0, 0.0)..multiply(Matrix4.diagonal3Values(1.02, 1.02, 1.0)))
                  : Matrix4.identity(),
              child: InkWell(
                onTap: () {},
                onHover: (v) => setState(() => _isHovered = v),
                borderRadius: BorderRadius.circular(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.16),
                                  color.withValues(alpha: 0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(widget.icon, size: 16, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: targetVal),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, animVal, _) {
                          final displayStr = _formatValue(animVal, targetVal, prefix, suffix, hasComma, isDecimal);
                          return Text(
                            displayStr,
                            style: AppTextStyles.statValue(isDark).copyWith(
                              fontSize: 24,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.label,
                        style: AppTextStyles.statLabel(isDark).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

