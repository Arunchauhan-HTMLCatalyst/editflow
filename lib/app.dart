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
    // In-app bottom notification snackbars disabled per request
    return child;
  }
}
