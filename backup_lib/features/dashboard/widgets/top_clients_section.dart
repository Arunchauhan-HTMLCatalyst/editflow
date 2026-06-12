import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../clients/models/client.dart';

class TopClientData {
  final Client client;
  final double revenue;
  final double percentage;

  const TopClientData({
    required this.client,
    required this.revenue,
    required this.percentage,
  });
}

class TopClientsSection extends StatelessWidget {
  final List<TopClientData> clients;
  final String Function(double) formatValue;

  const TopClientsSection({
    super.key,
    required this.clients,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Clients', style: AppTextStyles.title3(isDark)),
                Text('by revenue', style: AppTextStyles.small(isDark)),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            if (clients.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text('No data yet', style: AppTextStyles.small(isDark)),
                ),
              )
            else
              ...clients.asMap().entries.map((entry) => _ClientRankItem(
                    rank: entry.key + 1,
                    data: entry.value,
                    isDark: isDark,
                    formatValue: formatValue,
                    onTap: () => context.push('/clients/${entry.value.client.id}'),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ClientRankItem extends StatelessWidget {
  final int rank;
  final TopClientData data;
  final bool isDark;
  final String Function(double) formatValue;
  final VoidCallback onTap;

  const _ClientRankItem({
    required this.rank,
    required this.data,
    required this.isDark,
    required this.formatValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textMuted : Color(0xFF71717A),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Center(
                child: Text(
                  data.client.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.client.name,
                    style: AppTextStyles.label(isDark).copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.client.company != null)
                    Text(
                      data.client.company!,
                      style: AppTextStyles.small(isDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatValue(data.revenue),
                  style: AppTextStyles.label(isDark).copyWith(fontSize: 13),
                ),
                Text(
                  '${data.percentage.toStringAsFixed(0)}%',
                  style: AppTextStyles.small(isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
