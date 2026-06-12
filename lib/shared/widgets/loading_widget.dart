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
        padding: const EdgeInsets.all(20.0),
        itemCount: 3,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: ShimmerCard(
              height: 108,
              borderRadius: 16.0,
            ),
          );
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

