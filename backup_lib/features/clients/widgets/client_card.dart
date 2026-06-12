import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../settings/models/currency_config.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  final double totalRevenue;
  final double pendingRevenue;
  final int projectCount;
  final CurrencyConfig? currency;

  const ClientCard({
    super.key,
    required this.client,
    required this.onTap,
    required this.totalRevenue,
    required this.pendingRevenue,
    required this.projectCount,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = currency ?? CurrencyConfig.usd;
    final initials = client.name.isNotEmpty
        ? client.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';
    final hasContact = client.email != null || client.phone != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + call button
              Row(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: AppTextStyles.label(isDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (client.company != null)
                          Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Text(client.company!, style: AppTextStyles.small(isDark), maxLines: 1),
                          ),
                      ],
                    ),
                  ),
                  if (client.phone != null)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chat_rounded, size: 18, color: const Color(0xFF25D366)),
                        onPressed: () => launchUrl(Uri.parse('https://wa.me/${client.phone}')),
                        tooltip: 'WhatsApp ${client.phone}',
                        constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                ],
              ),

              // Stats row
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _chip(c.format(totalRevenue), 'Revenue', AppColors.success, isDark),
                  SizedBox(width: AppSpacing.sm),
                  if (pendingRevenue > 0)
                    _chip(c.format(pendingRevenue), 'Pending', AppColors.warning, isDark),
                  if (pendingRevenue > 0) SizedBox(width: AppSpacing.sm),
                  _chip('$projectCount', 'Project${projectCount == 1 ? '' : 's'}', AppColors.primary, isDark),
                ],
              ),

              // Contact details
              if (hasContact) ...[
                SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: isDark ? AppColors.border.withValues(alpha: 0.4) : const Color(0xFFE4E4E7)),
                SizedBox(height: AppSpacing.sm),
                if (client.email != null)
                  _contactLine(Icons.email_outlined, client.email!, AppColors.textMuted),
                if (client.email != null && client.phone != null) SizedBox(height: 4),
                if (client.phone != null)
                  _contactLine(Icons.phone_outlined, client.phone!, AppColors.textMuted),
                SizedBox(height: 4),
              ],

            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String value, String label, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.statusBg(color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _contactLine(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
