import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/currency_config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../projects/providers/project_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../projects/models/project.dart';
import '../../clients/models/client.dart';
import '../../../shared/providers/computed_providers.dart';
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
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
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
                        color: isDark ? AppColors.surface : CupertinoColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
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
              Card(
                elevation: 0,
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
                                Text(
                                  fullName ?? (user?.email?.split('@').first ?? 'User'),
                                  style: AppTextStyles.body(isDark).copyWith(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  user?.email ?? 'No email',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.textSecondary
                                        : const Color(0xFF64748B),
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
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: CupertinoIcons.calendar_today,
                        label: 'Member since',
                        value: createdStr,
                        isDark: isDark,
                        context: context,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: CupertinoIcons.time,
                        label: 'Last sign in',
                        value: lastSignInStr,
                        isDark: isDark,
                        context: context,
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
                      ),
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
                      final tempDir = Directory.systemTemp;
                      final file = File('${tempDir.path}/editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json');
                      await file.writeAsString(jsonStr);
                      await SharePlus.instance.share(ShareParams(
                        files: [XFile(file.path)],
                        text: 'EditFlow Data Backup',
                      ));
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

                        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
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
                        } else if (Platform.isIOS) {
                          final docsDir = await getApplicationDocumentsDirectory();
                          final fileName = 'editflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
                          final file = File('${docsDir.path}/$fileName');
                          await file.writeAsString(jsonStr);
                          savedFilePath = file.path;
                        } else if (Platform.isAndroid) {
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
                                content: Text(Platform.isIOS 
                                    ? 'Backup saved! Open Files app -> On My iPhone -> Editflow'
                                    : 'Backup saved directly to downloads folder!'),
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
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
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
              color: isDark ? AppColors.primary : const Color(0xFF0D9488),
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
                    Icons.switch_account_rounded,
                    size: 18,
                    color: isDark ? AppColors.primary : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
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
              ],
            ),
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

