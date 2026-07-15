import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/currency_config.dart';
import 'dart:convert';
import 'dart:io';
import '../../../shared/utils/web_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../projects/providers/project_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../projects/models/project.dart';
import '../../clients/models/client.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/utils/premium_helper.dart';
import '../../../services/supabase_service.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final fullName = user?.userMetadata?['full_name'] as String?;

    final createdDateTime = user != null ? DateTime.tryParse(user.createdAt) : null;
    final createdStr = createdDateTime != null ? DateFormat('MMMM yyyy').format(createdDateTime) : 'N/A';

    final lastSignInTime = user?.lastSignInAt != null ? DateTime.tryParse(user!.lastSignInAt!) : null;
    final lastSignInStr = lastSignInTime != null ? DateFormat('MMM d, h:mm a').format(lastSignInTime.toLocal()) : 'Just now';

    final provider = user?.appMetadata['provider'] as String? ?? 'email';
    final isGoogle = provider == 'google';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlowContainer(
        child: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: EdgeInsets.fromLTRB(
                AppLayout.pagePadding(context),
                AppLayout.pagePadding(context),
                AppLayout.pagePadding(context),
                AppLayout.pagePadding(context) + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header with Back Button
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.back,
                        size: 18,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: AppTextStyles.title1(isDark).copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 44.0),
                child: Text(
                  'Manage your preferences and data',
                  style: AppTextStyles.caption(isDark).copyWith(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // PROFILE SECTION
              Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF171D1F), const Color(0xFF101517)]
                        : [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: isDark ? AppColors.border : AppColors.primary.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.primaryGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: isDark
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          )
                                        ],
                                ),
                                child: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(32),
                                        child: Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Center(
                                            child: Text(
                                              (fullName?.isNotEmpty == true
                                                  ? fullName![0].toUpperCase()
                                                  : (user?.email?.isNotEmpty == true
                                                      ? user!.email![0].toUpperCase()
                                                      : '?')),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          (fullName?.isNotEmpty == true
                                              ? fullName![0].toUpperCase()
                                              : (user?.email?.isNotEmpty == true
                                                  ? user!.email![0].toUpperCase()
                                                  : '?')),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF171D1F) : Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.success.withValues(alpha: 0.45),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        fullName ?? (user?.email?.split('@').first ?? 'User'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (authState.isPro) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryNeon.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3), width: 0.8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.sparkles, color: AppColors.primaryNeon, size: 9),
                                            SizedBox(width: 3),
                                            Text(
                                              'PRO',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.primaryNeon,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user?.email ?? 'No email',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.surface
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          isGoogle 
                                                ? Image.asset(
                                                    'assets/images/google_logo.png',
                                                    width: 12,
                                                    height: 12,
                                                  )
                                                : Icon(
                                                    Icons.key_rounded,
                                                    size: 14,
                                                    color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                                                  ),
                                            const SizedBox(width: 4),
                                          Text(
                                            provider.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.2),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified_user_rounded,
                                            size: 11,
                                            color: AppColors.success,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'VERIFIED',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.success,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: CupertinoIcons.calendar_today,
                        label: 'Member since',
                        value: createdStr,
                        isDark: isDark,
                        context: context,
                        inverse: true,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: CupertinoIcons.time,
                        label: 'Last sign in',
                        value: lastSignInStr,
                        isDark: isDark,
                        context: context,
                        inverse: true,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: CupertinoIcons.number,
                        label: 'User ID',
                        value: user?.id != null 
                            ? '#EF-${user!.id.substring(0, 8).toUpperCase()}'
                            : 'N/A',
                        isDark: isDark,
                        isCopyable: true,
                        rawToCopy: user?.id,
                        context: context,
                        inverse: true,
                      ),
                      if (!authState.isPro) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.info_circle_fill,
                                  color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EditFlow Free Plan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13, 
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Limits: max 5 clients & 10 projects',
                                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNeon,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  elevation: 0,
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () {
                                  PremiumHelper.showUpgradeOptionsModal(context);
                                },
                                child: const Text(
                                  'Upgrade',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'WORKSPACE PLANS COMPARISON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Free Tier',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  Text(
                                    'Max 5 Clients & 10 Projects',
                                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const Divider(color: AppColors.border, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Text(
                                        'Pro Tier (Monthly / Yearly)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryNeon),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(CupertinoIcons.sparkles, color: AppColors.primaryNeon, size: 10),
                                    ],
                                  ),
                                  const Text(
                                    'Unlimited Clients & Projects',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (authState.premiumUntil != null && authState.role != 'admin') ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryNeon.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.18),
                                AppColors.primaryNeon.withValues(alpha: 0.18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNeon.withValues(alpha: 0.15),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNeon.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryNeon.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.sparkles,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'EDITFLOW PRO ACTIVE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900, 
                                        fontSize: 13.5, 
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Active benefits until ${DateFormat('MMMM dd, yyyy').format(authState.premiumUntil!.toLocal())}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // PREFERENCES SECTION
              Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.cardPadding,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.dark_mode_rounded,
                              size: 18,
                              color: isDark ? AppColors.primary : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isDark,
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: isDark
                            ? const Color(0xFF252538)
                            : const Color(0xFFE2E8F0),
                        onChanged: (_) => ref
                            .read(settingsProvider.notifier)
                            .toggleDarkMode(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CurrencyPicker(
                currency: currency,
                isDark: isDark,
                onChanged: (c) =>
                    ref.read(settingsProvider.notifier).setCurrency(c),
              ),
              const SizedBox(height: 12),
              _MonthlyGoalCard(
                goal: settings.monthlyGoal,
                isDark: isDark,
                onChanged: (g) =>
                    ref.read(settingsProvider.notifier).setMonthlyGoal(g),
              ),
              const SizedBox(height: 12),
              _ClientModeCard(
                isClientMode: settings.isClientMode,
                isDark: isDark,
                onChanged: (_) => ref.read(settingsProvider.notifier).toggleClientMode(),
              ),
              if (!settings.isClientMode) ...[
                const SizedBox(height: 12),
                _UpiIdCard(
                  upiId: settings.upiId,
                  isDark: isDark,
                  onChanged: (u) =>
                      ref.read(settingsProvider.notifier).setUpiId(u),
                ),
              ],
              const SizedBox(height: 24),

              // DATA SECTION
              Text(
                'DATA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsItem(
                icon: Icons.share_rounded,
                label: 'Share EditFlow',
                subtitle: 'Tell others about this app',
                isDark: isDark,
                onTap: () => _shareApp(context),
              ),
               if (!settings.isClientMode) ...[
                const SizedBox(height: 8),
                _SettingsItem(
                  icon: Icons.upload_file_rounded,
                  label: 'Export Data',
                  subtitle: 'Export your clients and projects',
                  isDark: isDark,
                  onTap: () => _exportData(context, ref),
                ),
                const SizedBox(height: 8),
                _SettingsItem(
                  icon: Icons.download_rounded,
                  label: 'Import Data',
                  subtitle: 'Restore data from a backup file',
                  isDark: isDark,
                  onTap: () => _importData(context, ref),
                ),
              ],
              // HELP & SUPPORT SECTION
              Text(
                'HELP & SUPPORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsItem(
                icon: Icons.question_answer_rounded,
                label: 'FAQ / Help Center',
                subtitle: 'Frequently Asked Questions & Guides',
                isDark: isDark,
                onTap: () => _showFAQBottomSheet(context, isDark),
              ),
              const SizedBox(height: 8),
              _SettingsItem(
                icon: Icons.support_agent_rounded,
                label: 'Contact Support & Feedback',
                subtitle: 'Email support, bug reports, and features',
                isDark: isDark,
                onTap: () => _showSupportBottomSheet(context, ref, isDark),
              ),
              const SizedBox(height: 32),

              // SIGN OUT BUTTON
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
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Future<void> _shareApp(BuildContext context) async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: 'Check out EditFlow - the ultimate premium freelance workflow and invoice management app! Manage your clients, projects, payments, and deadlines: https://github.com/arunchauhan/editflow',
        subject: 'EditFlow App',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final clientsRepo = ref.read(clientRepositoryProvider);
      final projectsRepo = ref.read(projectRepositoryProvider);
      
      final clients = await clientsRepo.getAll();
      final projects = await projectsRepo.getAll();
      
      final userId = SupabaseService.userId;
      final activitiesResponse = await SupabaseService.instance
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      
      final activitiesList = activitiesResponse as List? ?? [];

      final backupData = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'clients': clients.map((c) => c.toJson()).toList(),
        'projects': projects.map((p) => p.toJson()).toList(),
        'activities': activitiesList,
      };

      final jsonStr = jsonEncode(backupData);
      if (!context.mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : const Color(0xFFF4FDFB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to export your EditFlow data backup.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                // Share Option
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      Navigator.pop(context);
                      if (kIsWeb) {
                        final bytes = utf8.encode(jsonStr);
                        final base64Str = base64Encode(bytes);
                        final fileName = 'editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
                        downloadFileWeb(
                          base64Data: base64Str,
                          fileName: fileName,
                          mimeType: 'application/json',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Backup JSON downloaded to your computer!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } else {
                        final tempDir = Directory.systemTemp;
                        final file = File('${tempDir.path}/editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json');
                        await file.writeAsString(jsonStr);
                        await SharePlus.instance.share(ShareParams(
                          files: [XFile(file.path)],
                          text: 'EditFlow Data Backup',
                        ));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFEEF2F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.share_rounded,
                              size: 18,
                              color: isDark ? AppColors.primary : const Color(0xFF0D9488),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Share Backup File',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Send via email, message, or copy to clipboard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Download Option
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        String? savedFilePath;

                        if (kIsWeb) {
                          final bytes = utf8.encode(jsonStr);
                          final base64Str = base64Encode(bytes);
                          final fileName = 'editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
                          downloadFileWeb(
                            base64Data: base64Str,
                            fileName: fileName,
                            mimeType: 'application/json',
                          );
                          savedFilePath = 'web_download';
                        } else if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
                          try {
                            savedFilePath = await FilePicker.platform.saveFile(
                              dialogTitle: 'Select download location:',
                              fileName: 'editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json',
                              type: FileType.custom,
                              allowedExtensions: ['json'],
                            );
                            if (savedFilePath != null) {
                              final file = File(savedFilePath);
                              await file.writeAsString(jsonStr);
                            }
                          } catch (e) {
                            savedFilePath = null;
                          }
                        } else if (!kIsWeb && Platform.isIOS) {
                          final docsDir = await getApplicationDocumentsDirectory();
                          final fileName = 'editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
                          final file = File('${docsDir.path}/$fileName');
                          await file.writeAsString(jsonStr);
                          savedFilePath = file.path;
                        } else if (!kIsWeb && Platform.isAndroid) {
                          try {
                            final downloadsDir = Directory('/storage/emulated/0/Download');
                            if (await downloadsDir.exists()) {
                              final fileName = 'editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
                              final file = File('${downloadsDir.path}/$fileName');
                              await file.writeAsString(jsonStr);
                              savedFilePath = file.path;
                            } else {
                              final extDir = await getExternalStorageDirectory();
                              if (extDir != null) {
                                final file = File('${extDir.path}/editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json');
                                await file.writeAsString(jsonStr);
                                savedFilePath = file.path;
                              }
                            }
                          } catch (e) {
                            savedFilePath = null;
                          }
                        }
 
                        if (savedFilePath != null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(kIsWeb
                                    ? 'Backup JSON downloaded successfully!'
                                    : ((!kIsWeb && Platform.isIOS) 
                                        ? 'Backup saved! Open Files app -> On My iPhone -> Editflow'
                                        : 'Backup saved directly to downloads folder!')),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } else {
                          final tempDir = Directory.systemTemp;
                          final backupFile = File('${tempDir.path}/editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json');
                          await backupFile.writeAsString(jsonStr);
 
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Direct download failed. Opening share sheet to save...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          await SharePlus.instance.share(ShareParams(
                            files: [XFile(backupFile.path)],
                            text: 'EditFlow Data Backup',
                          ));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save file: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primaryNeon.withValues(alpha: 0.15) : const Color(0xFFEEF2F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: isDark ? AppColors.primaryNeon : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Save to Device (Download)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Download backup file directly to local folder',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null) {
        return;
      }

      final filePart = result.files.single;
      if (filePart.path == null && filePart.bytes == null) {
        return;
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Importing Backup Data...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Please do not close the app'),
                  ],
                ),
              ),
            ),
          );
        },
      );

      String jsonStr;
      if (filePart.bytes != null) {
        jsonStr = utf8.decode(filePart.bytes!);
      } else {
        final file = File(filePart.path!);
        jsonStr = await file.readAsString();
      }
      final Map<String, dynamic> backupData = jsonDecode(jsonStr);

      if (backupData['clients'] is! List || backupData['projects'] is! List) {
        throw const FormatException('Invalid backup file format. Missing clients or projects list.');
      }

      final clientsList = backupData['clients'] as List;
      final projectsList = backupData['projects'] as List;
      final activitiesList = backupData['activities'] as List? ?? [];

      final clientsRepo = ref.read(clientRepositoryProvider);
      final projectsRepo = ref.read(projectRepositoryProvider);
      final userId = SupabaseService.userId;

      final currentClients = await clientsRepo.getAll();
      final currentClientsMap = {for (var c in currentClients) c.name.toLowerCase(): c.id};

      final clientIdMap = <String, String>{};
      final projectIdMap = <String, String>{};
      int importedClientsCount = 0;
      int importedProjectsCount = 0;

      for (final clientJson in clientsList) {
        final clientMap = Map<String, dynamic>.from(clientJson);
        final oldId = clientMap['id'] as String;
        final clientName = clientMap['name'] as String;

        if (currentClientsMap.containsKey(clientName.toLowerCase())) {
          clientIdMap[oldId] = currentClientsMap[clientName.toLowerCase()]!;
        } else {
          clientMap['user_id'] = userId;
          clientMap['created_at'] ??= DateTime.now().toIso8601String();
          clientMap['updated_at'] ??= DateTime.now().toIso8601String();
          final clientObj = Client.fromJson(clientMap);
          final createdClient = await clientsRepo.create(clientObj);
          clientIdMap[oldId] = createdClient.id;
          importedClientsCount++;
        }
      }

      final currentProjects = await projectsRepo.getAll();
      final currentProjectsSet = {
        for (var p in currentProjects) '${p.name.toLowerCase()}_${p.clientId}'
      };

      for (final projectJson in projectsList) {
        final projectMap = Map<String, dynamic>.from(projectJson);
        final oldProjectId = projectMap['id'] as String;
        final projectName = projectMap['name'] as String;
        final oldClientId = projectMap['client_id'] as String;
        
        final newClientId = clientIdMap[oldClientId];
        if (newClientId == null) {
          continue;
        }

        final projectKey = '${projectName.toLowerCase()}_$newClientId';
        if (currentProjectsSet.contains(projectKey)) {
          final existingProject = currentProjects.firstWhere(
            (p) => p.name.toLowerCase() == projectName.toLowerCase() && p.clientId == newClientId
          );
          projectIdMap[oldProjectId] = existingProject.id;
          continue;
        }

        projectMap['user_id'] = userId;
        projectMap['client_id'] = newClientId;
        projectMap.remove('client_name');
        projectMap['created_at'] ??= DateTime.now().toIso8601String();
        projectMap['updated_at'] ??= DateTime.now().toIso8601String();

        final projectObj = Project.fromJson(projectMap);
        final createdProject = await projectsRepo.create(projectObj);
        projectIdMap[oldProjectId] = createdProject.id;
        importedProjectsCount++;
      }

      if (activitiesList.isNotEmpty) {
        for (final actJson in activitiesList) {
          final actMap = Map<String, dynamic>.from(actJson);
          final String? oldRefId = actMap['reference_id'];
          final String? refType = actMap['reference_type'];
          
          String? newRefId = oldRefId;
          if (oldRefId != null) {
            if (refType == 'client') {
              newRefId = clientIdMap[oldRefId];
            } else if (refType == 'project') {
              newRefId = projectIdMap[oldRefId];
            }
          }

          await SupabaseService.instance.from('activities').insert({
            'user_id': userId,
            'type': actMap['type'],
            'description': actMap['description'],
            'reference_id': newRefId,
            'reference_type': refType,
          }).timeout(const Duration(seconds: 5));
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
      }

      ref.invalidate(projectProvider);
      ref.invalidate(clientProvider);
      ref.invalidate(paymentOverviewProvider);
      ref.invalidate(recentActivityProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $importedClientsCount clients and $importedProjectsCount projects successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isCopyable = false,
    String? rawToCopy,
    required BuildContext context,
    bool inverse = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: inverse ? Colors.white.withValues(alpha: 0.6) : (isDark ? AppColors.textMuted : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: inverse ? Colors.white.withValues(alpha: 0.8) : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: inverse ? Colors.white : (isDark ? AppColors.textPrimary : const Color(0xFF0F172A)),
          ),
        ),
        if (isCopyable && rawToCopy != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: rawToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('User ID copied to clipboard!'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Icon(
              Icons.copy_rounded,
              size: 14,
              color: inverse ? Colors.white : (isDark ? AppColors.primary : const Color(0xFF0D9488)),
            ),
          ),
        ],
      ],
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
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.currency_exchange_rounded,
                    size: 18,
                    color: isDark ? AppColors.primary : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Currency',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _showPicker(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${currency.symbol} ${currency.code}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
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
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.only(bottom: 8),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: CurrencyConfig.supported.map((c) {
                    final isSelected = c.code == currency.code;
                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${c.symbol}  ${c.code} — ${c.name}',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.textPrimary : const Color(0xFF0F172A)),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 20)
                              : null,
                          onTap: () {
                            onChanged(c);
                            Navigator.of(ctx).pop();
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark 
                              ? AppColors.border.withValues(alpha: 0.5) 
                              : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              ListTile(
                title: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
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
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDark ? AppColors.primary : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
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
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.flag_rounded,
                size: 18,
                color: widget.isDark ? AppColors.primary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Monthly Goal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppColors.border
                          : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: widget.isDark
                      ? const Color(0xFF1E1E2C)
                      : const Color(0xFFF1F5F9),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
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

class _ClientModeCard extends StatelessWidget {
  final bool isClientMode;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ClientModeCard({
    required this.isClientMode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFF1F5F9),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.switch_account_rounded,
                      size: 18,
                      color: isDark ? AppColors.primary : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Client View Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Simulate read-only client experience',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isClientMode,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
              inactiveTrackColor: isDark
                  ? const Color(0xFF252538)
                  : const Color(0xFFE2E8F0),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpiIdCard extends StatefulWidget {
  final String upiId;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _UpiIdCard({
    required this.upiId,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_UpiIdCard> createState() => _UpiIdCardState();
}

class _UpiIdCardState extends State<_UpiIdCard> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.upiId);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onChanged(_controller.text.trim());
    }
  }

  @override
  void didUpdateWidget(_UpiIdCard old) {
    super.didUpdateWidget(old);
    if (old.upiId != widget.upiId && !_focusNode.hasFocus) {
      _controller.text = widget.upiId;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? AppColors.border : const Color(0xFFF1F5F9),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: widget.isDark ? AppColors.primary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPI ID',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Receive direct bank transfers',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'e.g. user@upi',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppColors.border
                          : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: widget.isDark
                      ? const Color(0xFF1E1E2C)
                      : const Color(0xFFF1F5F9),
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
                onSubmitted: (v) {
                  widget.onChanged(v.trim());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Support configuration provider
final supportSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await SupabaseService.instance
        .from('system_settings')
        .select('value')
        .eq('key', 'support')
        .maybeSingle();
    if (response != null && response['value'] != null) {
      return response['value'] as Map<String, dynamic>;
    }
  } catch (e) {
    debugPrint('Error loading support settings: $e');
  }
  return {
    'email': 'editflow@acsoft.online',
    'hours': 'Monday – Friday\n10:00 AM – 6:00 PM (IST)',
    'response_time': 'Usually within 24–48 hours.'
  };
});

// Interactive sheet functions
void _showFAQBottomSheet(BuildContext context, bool isDark) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF101517) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.border : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildFAQCategory('Account', [
                        _FAQItem('I forgot my password.', 'Click "Forgot Password" on the login screen to receive a reset link via email, or contact support if you need manual assistance.', isDark),
                        _FAQItem('How do I delete my account?', 'Please contact our support team at editflow@acsoft.online to delete your account permanently.', isDark),
                      ], isDark),
                      _buildFAQCategory('Projects', [
                        _FAQItem('How do I create a project?', 'Tap the "+" floating button or "Add Project" inside the Projects tab. Fill in the title, description, and link a client.', isDark),
                        _FAQItem('How do I edit project details?', 'Open the project details page and tap the Edit (pencil) icon at the top right to modify any parameters.', isDark),
                        _FAQItem('How do I delete a project?', 'Inside the project editor screen, scroll to the bottom and select "Delete Project". Confirm your choice in the dialog.', isDark),
                        _FAQItem('Can I restore a deleted project?', 'Deleted projects are immediately wiped for security reasons and cannot be restored. Please proceed with caution.', isDark),
                      ], isDark),
                      _buildFAQCategory('Clients', [
                        _FAQItem('How do I add a client?', 'Go to the Clients tab and tap the "+" button. Provide their company name, primary contact name, email, and billing info.', isDark),
                        _FAQItem('Can a client have multiple projects?', 'Yes, a client profile can be linked to any number of active or archived projects.', isDark),
                        _FAQItem('How do I remove a client?', 'Open the Client detail screen and tap "Remove Client" from the option actions. You can only remove clients who have no active reviews.', isDark),
                      ], isDark),
                      _buildFAQCategory('Video Reviews', [
                        _FAQItem('How do timestamp comments work?', 'When clients watch a video review, they can type comments. The comment is automatically timestamped at the current playhead position.', isDark),
                        _FAQItem('How do I generate a review link?', 'Open the project page, select "Create Review", upload the video asset, and tap "Generate Link". Copy and share this with your client.', isDark),
                        _FAQItem('Can clients review without an account?', 'Yes! Review links are guest-friendly, enabling clients to comment and approve without signing up.', isDark),
                        _FAQItem('Why has my review link expired?', 'Review links expire automatically based on the expiration duration configured when creating the link.', isDark),
                        _FAQItem('How do I mark a project as completed?', 'Open the project detail page and change the pipeline status toggle to "Completed".', isDark),
                      ], isDark),
                      _buildFAQCategory('Payments & Invoices', [
                        _FAQItem('How do I generate an invoice?', 'Select the project, click "Generate Invoice", configure the items/fees, and save to output a premium PDF layout.', isDark),
                        _FAQItem('How does the UPI QR payment work?', 'When you add your UPI ID in Settings, invoices generate a scan-to-pay QR code for instant client settlements.', isDark),
                        _FAQItem('Can I regenerate an invoice?', 'Yes, invoices can be re-edited or re-downloaded at any time from the payment details tab.', isDark),
                      ], isDark),
                      _buildFAQCategory('Security', [
                        _FAQItem('Is my data secure?', 'All user profiles, projects, and invoices are protected by database Row-Level Security (RLS) policies.', isDark),
                        _FAQItem('Who can access my projects?', 'Only you and users you share explicit guest review links with can access your project assets.', isDark),
                        _FAQItem('Are guest review links secure?', 'Yes, guest review links use cryptographically secure random UUID slugs to prevent unauthorized discovery.', isDark),
                      ], isDark),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildFAQCategory(String title, List<Widget> items, bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.primaryNeon : AppColors.primary,
            letterSpacing: 1.0,
          ),
        ),
      ),
      ...items,
    ],
  );
}

Widget _FAQItem(String question, String answer, bool isDark) {
  return Theme(
    data: ThemeData(
      dividerColor: Colors.transparent,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
          child: Text(
            answer,
            style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.textSecondary : const Color(0xFF475569), height: 1.4),
          ),
        ),
      ],
    ),
  );
}

void _showSupportBottomSheet(BuildContext context, WidgetRef ref, bool isDark) {
  final supportAsync = ref.read(supportSettingsProvider);
  final supportInfo = supportAsync.valueOrNull ?? {
    'email': 'editflow@acsoft.online',
    'hours': 'Monday – Friday\n10:00 AM – 6:00 PM (IST)',
    'response_time': 'Usually within 24–48 hours.'
  };
  
  final email = supportInfo['email'] ?? 'editflow@acsoft.online';
  final hours = supportInfo['hours'] ?? 'Monday – Friday\n10:00 AM – 6:00 PM (IST)';
  final responseTime = supportInfo['response_time'] ?? 'Usually within 24–48 hours.';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF101517) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.border : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Support & Feedback',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Contact Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.border : const Color(0xFFE2E8F0), width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CONTACT SUPPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryNeon : AppColors.primary)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.email_rounded, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Text(email, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: email));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Support email copied to clipboard!')),
                                  );
                                },
                                child: Icon(Icons.copy_rounded, size: 12, color: isDark ? AppColors.primaryNeon : AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text('BUSINESS HOURS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(hours, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 10),
                          const Text('RESPONSE TIME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(responseTime, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick forms
                    const Text('SUBMIT A REQUEST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    
                    // Simple Interactive Form
                    _SupportRequestForm(isDark: isDark),
                    const SizedBox(height: 24),
                    
                    // Version info
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 16),
                    Text('ABOUT EDITFLOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryNeon : AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(
                      'EditFlow is an all-in-one workspace built for freelance video editors to manage clients, projects, reviews, invoices, payments, and collaboration from one platform.',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondary : Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text('VERSION INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('• Current Version: v2.0\n• Platform: Web & Android\n• Last Updated: July 2026', style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

class _SupportRequestForm extends StatefulWidget {
  final bool isDark;
  const _SupportRequestForm({required this.isDark});

  @override
  State<_SupportRequestForm> createState() => _SupportRequestFormState();
}

class _SupportRequestFormState extends State<_SupportRequestForm> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'Technical Support';
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: widget.isDark ? AppColors.card : Colors.white,
            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Request Category',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            ),
            items: const [
              DropdownMenuItem(value: 'Technical Support', child: Text('Technical Support')),
              DropdownMenuItem(value: 'Bug Report', child: Text('Bug Report')),
              DropdownMenuItem(value: 'Feature Request', child: Text('Feature Request')),
              DropdownMenuItem(value: 'Billing', child: Text('Billing')),
              DropdownMenuItem(value: 'General Inquiry', child: Text('General Inquiry')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _category = val);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subjectController,
            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Subject',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Subject is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageController,
            maxLines: 4,
            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Description / Message Content',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              alignLabelWithHint: true,
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Description is required' : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Request Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final desc = '[$_category] Subject: ${_subjectController.text}\nDescription: ${_messageController.text}\nDevice: Web/Mobile\nApp Version: v2.0';
      await SupabaseService.instance.from('support_tickets').insert({
        'user_id': SupabaseService.userId,
        'description': desc,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket submitted successfully!')),
        );
        _subjectController.clear();
        _messageController.clear();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

