import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'router.dart';
import 'features/settings/providers/settings_provider.dart';
import 'shared/models/activity.dart';
import 'shared/providers/computed_providers.dart';

class EditFlowApp extends ConsumerWidget {
  const EditFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'EditFlow',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final content = settings.isDarkMode
            ? (child ?? const SizedBox())
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.bgLightGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: child,
              );
        return GlobalNotificationListener(child: content);
      },
    );
  }
}

class GlobalNotificationListener extends ConsumerWidget {
  final Widget child;
  const GlobalNotificationListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to activities globally to show in-app notification snackbars on Web
    ref.listen<AsyncValue<List<Activity>>>(recentActivityProvider, (previous, next) {
      if (!kIsWeb) return; // Native local notifications handle this on Android/iOS
      
      final prevList = previous?.valueOrNull ?? [];
      final nextList = next.valueOrNull ?? [];
      
      if (prevList.isEmpty && nextList.isNotEmpty) {
        // Initial load, do not spam snackbars for old historic activities
        return;
      }
      
      // Find new activities
      for (final act in nextList) {
        final isNew = !prevList.any((p) => p.id == act.id);
        if (isNew) {
          String icon = '🔔';
          if (act.type == 'comment_created') icon = '💬';
          if (act.type == 'project_created') icon = '📁';
          if (act.type == 'status_changed') icon = '🔄';
          if (act.type == 'payment_received') icon = '💰';
          if (act.type == 'due_date_overdue' || act.type == 'payment_overdue') icon = '⚠️';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      act.description,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'View',
                textColor: AppColors.primaryNeon,
                onPressed: () {
                  final routerObj = ref.read(routerProvider);
                  if (act.referenceType == 'project' && act.referenceId != null) {
                    routerObj.push('/projects/${act.referenceId}');
                  } else {
                    routerObj.push('/dashboard');
                  }
                },
              ),
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border, width: 0.8),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    return child;
  }
}
