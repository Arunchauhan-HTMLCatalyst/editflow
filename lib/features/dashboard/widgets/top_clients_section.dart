import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top Clients', style: AppTextStyles.title3(isDark)),
                  Text(
                    'by revenue',
                    style: AppTextStyles.small(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (clients.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('No data yet', style: AppTextStyles.small(isDark)),
                  ),
                )
              else
                Column(
                  children: clients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == clients.length - 1 ? 0 : 10.0,
                      ),
                      child: _ClientRankItem(
                        rank: index + 1,
                        data: data,
                        isDark: isDark,
                        formatValue: formatValue,
                        onTap: () => context.push('/clients/${data.client.id}'),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
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
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primaryNeon.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  data.client.name.isNotEmpty ? data.client.name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.client.name,
                    style: AppTextStyles.label(isDark).copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.client.company != null && data.client.company!.isNotEmpty)
                    Text(
                      data.client.company!,
                      style: AppTextStyles.small(isDark).copyWith(
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatValue(data.revenue),
                  style: AppTextStyles.label(isDark).copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${data.percentage.toStringAsFixed(0)}%',
                  style: AppTextStyles.small(isDark).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryNeon,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
