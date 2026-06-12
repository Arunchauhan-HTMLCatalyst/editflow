import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/currency_config.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
        padding: EdgeInsets.all(AppLayout.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppSpacing.sm),
            Text(
              'Profile',
              style: AppTextStyles.title2(isDark),
            ),
            SizedBox(height: AppSpacing.md),
            Card(
              color: isDark ? AppColors.surface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? AppColors.border : Color(0xFFE4E4E7),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          (user?.email?.isNotEmpty == true
                                  ? user!.email![0].toUpperCase()
                                  : '?'),
                          style: TextStyle(
                            fontSize: 22,
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
                            user?.email?.split('@').first ?? 'User',
                            style: AppTextStyles.label(isDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            user?.email ?? 'No email',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : Color(0xFF52525B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Preferences',
              style: AppTextStyles.title2(isDark),
            ),
            SizedBox(height: AppSpacing.md),
            Card(
              color: isDark ? AppColors.surface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? AppColors.border : Color(0xFFE4E4E7),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dark_mode,
                          size: 18,
                          color: isDark
                              ? AppColors.textPrimary
                              : Color(0xFF18181B),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? AppColors.textPrimary
                                : Color(0xFF18181B),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isDark,
                      activeTrackColor: AppColors.primary,
                      onChanged: (_) => ref.read(settingsProvider.notifier).toggleDarkMode(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            _CurrencyPicker(
              currency: currency,
              isDark: isDark,
              onChanged: (c) => ref.read(settingsProvider.notifier).setCurrency(c),
            ),
            SizedBox(height: AppSpacing.md),
            _MonthlyGoalCard(
              goal: settings.monthlyGoal,
              isDark: isDark,
              onChanged: (g) => ref.read(settingsProvider.notifier).setMonthlyGoal(g),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Data',
              style: AppTextStyles.title2(isDark),
            ),
            SizedBox(height: AppSpacing.md),
            _SettingsItem(
              icon: Icons.share_rounded,
              label: 'Share EditFlow',
              subtitle: 'Tell others about this app',
              isDark: isDark,
              onTap: () {},
            ),
            SizedBox(height: AppSpacing.sm),
            _SettingsItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              subtitle: 'Coming soon',
              isDark: isDark,
              onTap: () {},
            ),
            SizedBox(height: AppSpacing.sm),
            _SettingsItem(
              icon: Icons.download,
              label: 'Import Data',
              subtitle: 'Coming soon',
              isDark: isDark,
              onTap: () {},
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 18, color: AppColors.error),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    ),
  );
  }
}

class _CurrencyPicker extends StatelessWidget {
  final CurrencyConfig currency;
  final bool isDark;
  final ValueChanged<CurrencyConfig> onChanged;

  const _CurrencyPicker({
    required this.currency,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? AppColors.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.border : Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.currency_exchange,
                  size: 18,
                  color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Currency',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _showPicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252535) : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${currency.symbol} ${currency.code}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 12,
                      color: isDark ? AppColors.textMuted : Color(0xFF71717A),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Select Currency',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1),
            ...CurrencyConfig.supported.map((c) => ListTile(
              title: Text('${c.symbol}  ${c.code} — ${c.name}'),
              onTap: () {
                onChanged(c);
                Navigator.of(ctx).pop();
              },
            )),
            Divider(height: 1),
            ListTile(
              title: Text('Cancel', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? AppColors.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.border : Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252535) : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: isDark
                    ? AppColors.textPrimary
                    : Color(0xFF18181B)),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMuted : Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: isDark ? AppColors.textMuted : Color(0xFF71717A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyGoalCard extends StatefulWidget {
  final double goal;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _MonthlyGoalCard({
    required this.goal,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_MonthlyGoalCard> createState() => _MonthlyGoalCardState();
}

class _MonthlyGoalCardState extends State<_MonthlyGoalCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.goal.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_MonthlyGoalCard old) {
    super.didUpdateWidget(old);
    if (old.goal != widget.goal) {
      _controller.text = widget.goal.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.isDark ? AppColors.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isDark ? AppColors.border : Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.flag_rounded,
              size: 18,
              color: widget.isDark ? AppColors.textPrimary : Color(0xFF18181B),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Monthly Goal',
                style: TextStyle(
                  fontSize: 15,
                  color: widget.isDark ? AppColors.textPrimary : Color(0xFF18181B),
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: widget.isDark ? const Color(0xFF252535) : const Color(0xFFF1F3F5),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark ? AppColors.textPrimary : Color(0xFF18181B),
                ),
                onSubmitted: (v) {
                  final val = double.tryParse(v.trim());
                  if (val != null && val > 0) widget.onChanged(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
