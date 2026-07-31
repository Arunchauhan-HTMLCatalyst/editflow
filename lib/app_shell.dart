import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_layout.dart';

import 'shared/widgets/ef_logo.dart';
import 'shared/providers/computed_providers.dart';
import 'features/dashboard/screens/notification_center_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'services/supabase_service.dart';
import 'features/projects/providers/project_provider.dart';
import 'shared/utils/web_helper.dart';

final maintenanceProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final controller = StreamController<Map<String, dynamic>>();
  
  Future<void> fetch() async {
    try {
      final response = await SupabaseService.instance
          .from('system_settings')
          .select('value')
          .eq('key', 'maintenance')
          .maybeSingle();
      if (response != null && response['value'] != null) {
        if (!controller.isClosed) {
          controller.add(response['value'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.add({'enabled': false, 'message': ''});
      }
    }
  }

  fetch();

  final timer = Timer.periodic(const Duration(seconds: 20), (_) => fetch());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

final announcementProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final controller = StreamController<Map<String, dynamic>>();
  
  Future<void> fetch() async {
    try {
      final response = await SupabaseService.instance
          .from('system_settings')
          .select('value')
          .eq('key', 'announcement')
          .maybeSingle();
      if (response != null && response['value'] != null) {
        if (!controller.isClosed) {
          controller.add(response['value'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.add({'visible': false, 'text': ''});
      }
    }
  }

  fetch();

  final timer = Timer.periodic(const Duration(seconds: 20), (_) => fetch());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

class AppShell extends ConsumerStatefulWidget {
  final GoRouterState state;
  final Widget child;

  const AppShell({
    super.key,
    required this.state,
    required this.child,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[APPSHELL] App resumed - syncing profile data for upgrades...');
      ref.read(authProvider.notifier).syncProfileData();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final bottomInset = view.viewInsets.bottom;
      if (bottomInset == 0) {
        fixKeyboardGap();
      }
    } catch (_) {}
  }

  int _currentTab(String location, bool isClientMode) {
    if (isClientMode) {
      if (location.startsWith('/reviews')) return 1;
      if (location.startsWith('/clients')) return 2;
      return 0;
    }
    if (location.startsWith('/clients')) return 1;
    if (location.startsWith('/calendar')) return 2;
    if (location.startsWith('/payments')) return 3;
    return 0;
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    final isSecondPress = _lastBackPressed != null &&
        now.difference(_lastBackPressed!) < const Duration(seconds: 2);

    if (isSecondPress) {
      // Close app
      await SystemNavigator.pop();
      return true;
    }

    _lastBackPressed = now;
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Press back again to exit',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border, width: 0.8),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.state.uri.toString();
    final isClientMode = ref.watch(settingsProvider).isClientMode;
    final pendingReviewsCount = isClientMode
        ? (ref.watch(clientPendingReviewsProvider).valueOrNull?.length ?? 0)
        : 0;
    final currentIndex = _currentTab(location, isClientMode);
    
    final navItems = isClientMode
        ? const [
            _NavItem('Dashboard', Icons.grid_view_rounded),
            _NavItem('Reviews', Icons.rate_review_rounded),
            _NavItem('Freelancers', Icons.people_rounded),
          ]
        : const [
            _NavItem('Dashboard', Icons.grid_view_rounded),
            _NavItem('Clients', Icons.people_rounded),
            _NavItem('Calendar', Icons.calendar_month_rounded),
            _NavItem('Payments', Icons.credit_card_rounded),
          ];

    final isTablet = AppLayout.isTablet(context);
    final authState = ref.watch(authProvider);
    final maintenanceVal = ref.watch(maintenanceProvider).valueOrNull;
    final isMaintenanceMode = maintenanceVal?['enabled'] == true && !authState.isAdmin;

    final announcementVal = ref.watch(announcementProvider).valueOrNull;
    final isAnnouncementVisible = announcementVal?['visible'] == true && !authState.isAdmin;

    final bannerWidget = isMaintenanceMode
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.redAccent,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      maintenanceVal?['message'] ?? 'EditFlow is currently in Maintenance. Please donot do any activity in your editflow account.',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    final announcementBannerWidget = isAnnouncementVisible
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      announcementVal?['text'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    final widgetScaffold = isTablet
        ? Scaffold(
            body: Row(
              children: [
                _DesktopSidebar(
                  currentIndex: currentIndex,
                  navItems: navItems,
                  onTap: (index) {
                    HapticFeedback.selectionClick();
                    if (isClientMode) {
                      switch (index) {
                        case 0:
                          context.go('/dashboard');
                          break;
                        case 1:
                          context.go('/reviews');
                          break;
                        case 2:
                          context.go('/clients');
                          break;
                      }
                    } else {
                      switch (index) {
                        case 0:
                          context.go('/dashboard');
                        case 1:
                          context.go('/clients');
                        case 2:
                          context.go('/calendar');
                        case 3:
                          context.go('/payments');
                      }
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      bannerWidget,
                      announcementBannerWidget,
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            body: Column(
              children: [
                bannerWidget,
                announcementBannerWidget,
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.navBarMargin + 4),
                    child: widget.child,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _FloatingNavBar(
              currentIndex: currentIndex,
              navItems: navItems,
              pendingReviewsCount: pendingReviewsCount,
              onTap: (index) {
                HapticFeedback.selectionClick();
                if (isClientMode) {
                  switch (index) {
                    case 0:
                      context.go('/dashboard');
                      break;
                    case 1:
                      context.go('/reviews');
                      break;
                    case 2:
                      context.go('/clients');
                      break;
                  }
                } else {
                  switch (index) {
                    case 0:
                      context.go('/dashboard');
                    case 1:
                      context.go('/clients');
                    case 2:
                      context.go('/calendar');
                    case 3:
                      context.go('/payments');
                  }
                }
              },
            ),
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: widgetScaffold,
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final int pendingReviewsCount;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.navItems,
    required this.pendingReviewsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBarBgColor = isDark
        ? AppColors.elevated.withValues(alpha: 0.76)
        : Colors.white.withValues(alpha: 0.88);
    final navBarBorderColor = isDark
        ? AppColors.border.withValues(alpha: 0.35)
        : const Color(0xFFE2E8F0);
    final navBarShadows = isDark
        ? const <BoxShadow>[]
        : const [
            BoxShadow(
              color: Color(0x0C0F172A),
              blurRadius: 16,
              spreadRadius: 1,
              offset: Offset(0, 4),
            )
          ];

    final pillBgColors = isDark
        ? [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.primaryNeon.withValues(alpha: 0.08),
          ]
        : [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primaryNeon.withValues(alpha: 0.04),
          ];
    final pillBorderColor = isDark
        ? AppColors.primary.withValues(alpha: 0.25)
        : AppColors.primary.withValues(alpha: 0.15);
    final pillShadowColor = isDark
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.02);

    final activeIconColor = isDark ? AppColors.primaryNeon : AppColors.primary;
    final activeTextColor = isDark ? AppColors.textPrimary : AppColors.primary;
    final inactiveColor = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);
    final dotColor = isDark ? AppColors.primaryNeon : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: navBarBgColor,
              border: Border.all(color: navBarBorderColor, width: 0.8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: navBarShadows,
            ),
            child: Stack(
              children: [
                // Sliding background pill indicator
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    navItems.length > 1
                        ? -1.0 + (currentIndex * 2.0 / (navItems.length - 1))
                        : 0.0,
                    0.0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1.0 / navItems.length,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: pillBgColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pillBorderColor,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pillShadowColor,
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                // Tab Buttons
                Row(
                  children: List.generate(navItems.length, (index) {
                    final isActive = index == currentIndex;
                    final item = navItems[index];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedScale(
                                    scale: isActive ? 1.12 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      item.icon,
                                      size: 22,
                                      color: isActive ? activeIconColor : inactiveColor,
                                    ),
                                  ),
                                  if (item.label == 'Reviews' && pendingReviewsCount > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive ? activeTextColor : inactiveColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isActive ? 6 : 0,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: dotColor.withValues(alpha: 0.8),
                                      blurRadius: 4,
                                      spreadRadius: 0.5,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class _DesktopSidebar extends ConsumerWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final ValueChanged<int> onTap;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.navItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final fullName = user?.userMetadata?['full_name'] ?? 'User';
    final email = user?.email ?? '';

    final isClientMode = settings.isClientMode;
    final pendingReviewsCount = isClientMode
        ? (ref.watch(clientPendingReviewsProvider).valueOrNull?.length ?? 0)
        : 0;

    final sidebarBg = isDark
        ? AppColors.surface.withValues(alpha: 0.55)
        : const Color(0xFFF8FAFC).withValues(alpha: 0.85);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 250,
          decoration: BoxDecoration(
            color: sidebarBg,
            border: Border(
              right: BorderSide(
                color: isDark ? AppColors.border.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
        child: Column(
          children: [
            // App Logo Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const EfLogo(size: 36),
                  const SizedBox(width: 12),
                  const Text(
                    'EditFlow',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Mode Selector Widget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.card : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (isClientMode) {
                            ref.read(settingsProvider.notifier).toggleClientMode();
                            context.go('/dashboard');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: !isClientMode
                                ? (isDark ? AppColors.elevated : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: !isClientMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Freelancer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: !isClientMode ? FontWeight.bold : FontWeight.w600,
                                color: !isClientMode
                                    ? AppColors.primary
                                    : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isClientMode) {
                            ref.read(settingsProvider.notifier).toggleClientMode();
                            context.go('/dashboard');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isClientMode
                                ? (isDark ? AppColors.elevated : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isClientMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Client Portal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isClientMode ? FontWeight.bold : FontWeight.w600,
                                color: isClientMode
                                    ? AppColors.primary
                                    : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Navigation Items
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  final isActive = index == currentIndex;

                  final activeColor = isDark ? AppColors.primaryNeon : AppColors.primary;
                  final inactiveColor = isDark ? AppColors.textSecondary : const Color(0xFF64748B);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Material(
                        color: isActive
                            ? activeColor.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => onTap(index),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: isActive
                                  ? Border(
                                      left: BorderSide(
                                        color: activeColor,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                 Stack(
                                   clipBehavior: Clip.none,
                                   children: [
                                     Icon(
                                       item.icon,
                                       size: 18,
                                       color: isActive ? activeColor : inactiveColor,
                                     ),
                                     if (item.label == 'Reviews' && pendingReviewsCount > 0)
                                       Positioned(
                                         right: -2,
                                         top: -2,
                                         child: Container(
                                           width: 6,
                                           height: 6,
                                           decoration: const BoxDecoration(
                                             color: Colors.redAccent,
                                             shape: BoxShape.circle,
                                           ),
                                         ),
                                       ),
                                   ],
                                 ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                    color: isActive
                                        ? (isDark ? Colors.white : activeColor)
                                        : inactiveColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Profile / Settings / Log out
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (authState.isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/dashboard'),
                        icon: const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.white),
                        label: const Text('Admin Panel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          (fullName.isNotEmpty ? fullName[0] : (email.isNotEmpty ? email[0] : 'U')).toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: activeColorHelper(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/settings'),
                          icon: const Icon(Icons.settings_outlined, size: 14),
                          label: const Text('Settings', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : AppColors.primary,
                            side: BorderSide(
                              color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final activitiesAsync = ref.watch(recentActivityProvider);
                          final count = activitiesAsync.valueOrNull?.length ?? 0;
                          
                          final iconButton = IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black26,
                                builder: (context) {
                                  return Center(
                                    child: Container(
                                      width: 420,
                                      height: 600,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: const NotificationCenterScreen(isDialog: true),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.notifications_none_rounded, size: 16),
                            style: IconButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : AppColors.primary,
                              backgroundColor: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );

                          if (count > 0) {
                            return Badge(
                              label: Text('$count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                              backgroundColor: AppColors.error,
                              child: iconButton,
                            );
                          }
                          return iconButton;
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Color activeColorHelper(bool isDark) {
    return isDark ? AppColors.primaryNeon : AppColors.primary;
  }
}
