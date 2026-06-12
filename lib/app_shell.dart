import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/settings/providers/settings_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastBackPressed;

  int _currentTab(String location, bool isClientMode) {
    if (isClientMode) {
      if (location.startsWith('/clients')) return 1;
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
    final location = GoRouterState.of(context).uri.toString();
    final isClientMode = ref.watch(settingsProvider).isClientMode;
    final currentIndex = _currentTab(location, isClientMode);
    
    final navItems = isClientMode
        ? const [
            _NavItem('Dashboard', Icons.grid_view_rounded),
            _NavItem('Freelancers', Icons.people_rounded),
          ]
        : const [
            _NavItem('Dashboard', Icons.grid_view_rounded),
            _NavItem('Clients', Icons.people_rounded),
            _NavItem('Calendar', Icons.calendar_month_rounded),
            _NavItem('Payments', Icons.credit_card_rounded),
          ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.navBarMargin + 4),
          child: widget.child,
        ),
        bottomNavigationBar: _FloatingNavBar(
          currentIndex: currentIndex,
          navItems: navItems,
          onTap: (index) {
            HapticFeedback.selectionClick();
            if (isClientMode) {
              switch (index) {
                case 0:
                  context.go('/dashboard');
                case 1:
                  context.go('/clients');
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
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.navItems,
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
                              AnimatedScale(
                                scale: isActive ? 1.12 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  item.icon,
                                  size: 22,
                                  color: isActive ? activeIconColor : inactiveColor,
                                ),
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
