import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'shimmer_card.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool useShimmer;

  const LoadingWidget({
    super.key,
    this.message,
    this.useShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (useShimmer) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 4,
        itemBuilder: (context, index) {
          return _ShimmerRow(isDark: isDark);
        },
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textMuted,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: AppTextStyles.small(isDark),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single shimmer "card skeleton" that mimics a real list item:
///  ┌──────────────────────────────────────────┐
///  │ [●]  ████████████           ░░░░░░░ │
///  │      ████████                           │
///  │      ██████████████                     │
///  │                           ░░░░░░ ░░░░░ │
///  └──────────────────────────────────────────┘
class _ShimmerRow extends StatelessWidget {
  final bool isDark;

  const _ShimmerRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1F2E) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF2A2D3E) : const Color(0xFFE8ECF4);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                BoxShadow(
                  color: const Color(0xFFD0D9E8).withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: avatar + title + badge
          Row(
            children: [
              // Avatar circle
              ShimmerCard(width: 38, height: 38, borderRadius: 19),
              const SizedBox(width: 10),
              // Title + subtitle stacked
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCard(width: double.infinity, height: 13, borderRadius: 6),
                    const SizedBox(height: 6),
                    ShimmerCard(width: 120, height: 10, borderRadius: 5),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Badge pill
              ShimmerCard(width: 58, height: 22, borderRadius: 11),
            ],
          ),
          const SizedBox(height: 14),
          // Row 2: long body line
          ShimmerCard(width: double.infinity, height: 10, borderRadius: 5),
          const SizedBox(height: 6),
          ShimmerCard(width: 200, height: 10, borderRadius: 5),
          const SizedBox(height: 14),
          // Row 3: two pill "tag" placeholders + right-side meta
          Row(
            children: [
              ShimmerCard(width: 64, height: 20, borderRadius: 10),
              const SizedBox(width: 6),
              ShimmerCard(width: 50, height: 20, borderRadius: 10),
              const Spacer(),
              ShimmerCard(width: 70, height: 12, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }
}
