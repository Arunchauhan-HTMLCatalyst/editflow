import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ef_logo.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminShell extends ConsumerWidget {
  final GoRouterState state;
  final Widget child;

  const AdminShell({
    super.key,
    required this.state,
    required this.child,
  });

  int _getSelectedIndex(String location) {
    if (location.startsWith('/admin/dashboard')) return 0;
    if (location.startsWith('/admin/users')) return 1;
    if (location.startsWith('/admin/upgrades')) return 2;
    if (location.startsWith('/admin/support')) return 3;
    if (location.startsWith('/admin/storage')) return 4;
    if (location.startsWith('/admin/notifications')) return 5;
    if (location.startsWith('/admin/analytics')) return 6;
    if (location.startsWith('/admin/logs')) return 7;
    if (location.startsWith('/admin/settings')) return 8;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/admin/dashboard');
        break;
      case 1:
        context.go('/admin/users');
        break;
      case 2:
        context.go('/admin/upgrades');
        break;
      case 3:
        context.go('/admin/support');
        break;
      case 4:
        context.go('/admin/storage');
        break;
      case 5:
        context.go('/admin/notifications');
        break;
      case 6:
        context.go('/admin/analytics');
        break;
      case 7:
        context.go('/admin/logs');
        break;
      case 8:
        context.go('/admin/settings');
        break;
    }
  }

  String _getRouteTitle(String location) {
    if (location.startsWith('/admin/dashboard')) return 'Dashboard Overview';
    if (location.startsWith('/admin/users')) return 'User Directory';
    if (location.startsWith('/admin/upgrades')) return 'Upgrade Requests';
    if (location.startsWith('/admin/support')) return 'Support Tickets';
    if (location.startsWith('/admin/storage')) return 'Storage & Analytics';
    if (location.startsWith('/admin/notifications')) return 'Targeted Announcements';
    if (location.startsWith('/admin/analytics')) return 'System Metrics';
    if (location.startsWith('/admin/logs')) return 'System Audit Logs';
    if (location.startsWith('/admin/settings')) return 'Global App Settings';
    return 'Super Admin Panel';
  }

  void _triggerRefresh(WidgetRef ref, BuildContext context) {
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminUsersProvider(''));
    ref.invalidate(adminUpgradeRequestsProvider);
    ref.invalidate(adminStorageProvider);
    ref.invalidate(adminSettingsProvider);
    ref.invalidate(adminAnalyticsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing admin data...', style: TextStyle(fontWeight: FontWeight.bold)),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = state.uri.toString();
    final selectedIndex = _getSelectedIndex(location);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final fullName = user?.userMetadata?['full_name'] ?? 'Admin';
    final email = user?.email ?? '';

    final statsAsync = ref.watch(adminStatsProvider);
    final int pendingSupportCount = statsAsync.maybeWhen(
      data: (data) {
        final supportRequests = data['supportRequests'] as List? ?? [];
        return supportRequests.length;
      },
      orElse: () => 0,
    );

    final int pendingUpgradeCount = statsAsync.maybeWhen(
      data: (data) {
        final upgradeRequests = data['upgradeRequests'] as List? ?? [];
        return upgradeRequests.length;
      },
      orElse: () => 0,
    );

    final menuItems = [
      _AdminMenuItem('Dashboard', Icons.dashboard_rounded, 0),
      _AdminMenuItem('Users', Icons.people_alt_rounded, 1),
      _AdminMenuItem('Upgrade Requests', Icons.star_rounded, 2),
      _AdminMenuItem('Support Tickets', Icons.support_agent_rounded, 3),
      _AdminMenuItem('Storage', Icons.storage_rounded, 4),
      _AdminMenuItem('Notifications', Icons.campaign_rounded, 5),
      _AdminMenuItem('Analytics', Icons.analytics_rounded, 6),
      _AdminMenuItem('Audit Logs', Icons.receipt_long_rounded, 7),
      _AdminMenuItem('App Settings', Icons.settings_rounded, 8),
    ];

    Widget sidebarContent(BuildContext ctx) {
      return Container(
        color: AppColors.surface,
        child: Column(
          children: [
            // Header Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Row(
                children: [
                  const EfLogo(size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EditFlow',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SUPER ADMIN',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.redAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),

            // Navigation List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: menuItems.length,
                itemBuilder: (context, idx) {
                  final item = menuItems[idx];
                  final isSelected = selectedIndex == item.index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Material(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _onItemTapped(item.index, ctx);
                          if (!isDesktop) {
                            Navigator.of(ctx).pop(); // Close drawer on mobile
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: isSelected ? AppColors.primaryNeon : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (item.index == 2 && pendingUpgradeCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pendingUpgradeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (item.index == 3 && pendingSupportCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pendingSupportCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer profile and exit buttons
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.8),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNeon),
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
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border, width: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => context.go('/dashboard'),
                      icon: const Icon(Icons.exit_to_app_rounded, size: 13, color: Colors.redAccent),
                      label: const Text(
                        'Exit Admin Panel',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: Text(
                _getRouteTitle(location),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                  onPressed: () => _triggerRefresh(ref, context),
                ),
              ],
            )
          : null,
      drawer: !isDesktop
          ? Drawer(
              child: SafeArea(child: sidebarContent(context)),
            )
          : null,
      body: AmbientGlowContainer(
        child: Row(
          children: [
            if (isDesktop)
              SizedBox(
                width: 240,
                child: sidebarContent(context),
              ),
            if (isDesktop)
              const VerticalDivider(color: AppColors.border, width: 1),
            Expanded(
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuItem {
  final String title;
  final IconData icon;
  final int index;

  _AdminMenuItem(this.title, this.icon, this.index);
}
