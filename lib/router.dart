import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/connection_success_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/clients/screens/clients_screen.dart';
import 'features/clients/screens/client_detail_screen.dart';
import 'features/clients/screens/add_client_screen.dart';
import 'features/clients/screens/freelancer_detail_screen.dart';
import 'features/payments/screens/payments_screen.dart';
import 'features/projects/screens/project_detail_screen.dart';
import 'features/projects/screens/review_screen.dart';
import 'features/projects/screens/public_review_screen.dart';
import 'features/projects/screens/add_project_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/premium_callback_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/dashboard/screens/notification_center_screen.dart';
import 'features/dashboard/screens/client_reviews_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'services/supabase_service.dart';
import 'app_shell.dart';
import 'core/theme/app_transitions.dart';

// Admin screens
import 'features/admin/screens/admin_shell.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_users_screen.dart';
import 'features/admin/screens/admin_storage_screen.dart';
import 'features/admin/screens/admin_notifications_screen.dart';
import 'features/admin/screens/admin_logs_screen.dart';
import 'features/admin/screens/admin_settings_screen.dart';
import 'features/admin/screens/admin_support_screen.dart';
import 'features/admin/screens/admin_upgrades_screen.dart';
import 'features/admin/screens/admin_promo_codes_screen.dart';

class GoRouterRefreshListenable extends ChangeNotifier {
  GoRouterRefreshListenable(Ref ref) {
    ref.listen(
      authProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final loc = state.uri.toString();
      final path = state.uri.path;
      if (loc.contains('io.supabase.flutter') ||
          loc.contains('/callback?code=')) {
        return '/splash';
      }

      // Pre-emptively capture any invite code in query parameters
      final queryCode = state.uri.queryParameters['code'];
      if (queryCode != null && queryCode.isNotEmpty) {
        SupabaseService.pendingInviteCode = queryCode;
      }

      final isPublicRoute = path.startsWith('/share/review/');

      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/splash' ||
          isPublicRoute;

      final authState = ref.read(authProvider);
      final isUnauthenticated = authState.status == AuthStatus.unauthenticated;
      final isAuthenticated = authState.status == AuthStatus.authenticated;

      if (isUnauthenticated && !isAuthRoute) {
        final code = state.uri.queryParameters['code'] ?? SupabaseService.pendingInviteCode;
        if (code != null && code.isNotEmpty) {
          return '/login?code=$code';
        }
        return '/login';
      }

      if (isAuthenticated && isAuthRoute && path != '/splash' && !isPublicRoute) {
        final code = state.uri.queryParameters['code'] ?? SupabaseService.pendingInviteCode;
        if (code != null && code.isNotEmpty) {
          SupabaseService.pendingInviteCode = null; // Clear cached code once consumed
          return '/connection-success?code=$code';
        }
        return '/dashboard';
      }

      // Admin panel guard
      if (path.startsWith('/admin')) {
        if (!isAuthenticated || !authState.isAdmin) {
          return '/dashboard';
        }
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
    routes: [
      // ── Auth / utility screens ── slide up from bottom ──────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => slideUpPage(const SplashScreen(), key: state.pageKey),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return slideUpPage(LoginScreen(inviteCode: code), key: state.pageKey);
        },
      ),
      GoRoute(
        path: '/connection-success',
        pageBuilder: (context, state) {
          final code = state.uri.queryParameters['code'] ?? '';
          return slideUpPage(ConnectionSuccessScreen(inviteCode: code), key: state.pageKey);
        },
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => slideUpPage(const RegisterScreen(), key: state.pageKey),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => slideUpPage(const ForgotPasswordScreen(), key: state.pageKey),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => settingsPage(const SettingsScreen(), key: state.pageKey),
      ),
      GoRoute(
        path: '/premium-callback',
        pageBuilder: (context, state) {
          final sessionId = state.uri.queryParameters['session_id'];
          return slidePushPage(PremiumCallbackScreen(sessionId: sessionId), key: state.pageKey);
        },
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => slidePushPage(const NotificationCenterScreen(), key: state.pageKey),
      ),

      // Sheet-style creation screens → slide up from bottom
      GoRoute(
        path: '/projects/add',
        pageBuilder: (context, state) {
          final clientId = state.uri.queryParameters['clientId'];
          final freelancerId = state.uri.queryParameters['freelancerId'];
          final freelancerName = state.uri.queryParameters['freelancerName'];
          final parentId = state.uri.queryParameters['parentId'];
          final parentName = state.uri.queryParameters['parentName'];
          return slideUpPage(AddProjectScreen(
            preselectedClientId: clientId,
            preselectedFreelancerId: freelancerId,
            preselectedFreelancerName: freelancerName,
            parentId: parentId,
            parentProjectName: parentName,
          ), key: state.pageKey);
        },
      ),
      GoRoute(
        path: '/add-client',
        pageBuilder: (context, state) => slideUpPage(const AddClientScreen(), key: state.pageKey),
      ),

      // Detail screens → slide in from right
      GoRoute(
        path: '/clients/:id',
        pageBuilder: (context, state) => slidePushPage(ClientDetailScreen(
          clientId: state.pathParameters['id']!,
        ), key: state.pageKey),
      ),
      GoRoute(
        path: '/freelancers/:id',
        pageBuilder: (context, state) => slidePushPage(FreelancerDetailScreen(
          freelancerId: state.pathParameters['id']!,
        ), key: state.pageKey),
      ),
      GoRoute(
        path: '/projects/:id',
        pageBuilder: (context, state) => slidePushPage(ProjectDetailScreen(
          projectId: state.pathParameters['id']!,
        ), key: state.pageKey),
      ),
      GoRoute(
        path: '/projects/:projectId/reviews/:videoId',
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          final videoId = state.pathParameters['videoId']!;
          final isClientStr = state.uri.queryParameters['isClient'] ?? 'false';
          final isClient = isClientStr == 'true';
          return slidePushPage(ReviewScreen(
            projectId: projectId,
            videoId: videoId,
            isClient: isClient,
          ), key: state.pageKey);
        },
      ),
      GoRoute(
        path: '/share/review/:token',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token']!;
          return slidePushPage(PublicReviewScreen(shareToken: token), key: state.pageKey);
        },
      ),

      // ── Shell (bottom nav) ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            state: state,
            child: child,
          );
        },
        routes: [
          // Bottom-nav tabs → fade only (no slide)
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) {
              final code = state.uri.queryParameters['code'];
              return fadeTabPage(DashboardScreen(inviteCode: code), key: state.pageKey);
            },
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => fadeTabPage(const ClientsScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/reviews',
            pageBuilder: (context, state) => fadeTabPage(const ClientReviewsScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => fadeTabPage(const CalendarScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/payments',
            pageBuilder: (context, state) => fadeTabPage(const PaymentsScreen(), key: state.pageKey),
          ),
        ],
      ),

      // ── Admin Shell ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(
            state: state,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (context, state) => fadeTabPage(const AdminDashboardScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/users',
            pageBuilder: (context, state) => fadeTabPage(const AdminUsersScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/upgrades',
            pageBuilder: (context, state) => fadeTabPage(const AdminUpgradesScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/storage',
            pageBuilder: (context, state) => fadeTabPage(const AdminStorageScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/notifications',
            pageBuilder: (context, state) => fadeTabPage(const AdminNotificationsScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/logs',
            pageBuilder: (context, state) => fadeTabPage(const AdminLogsScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/support',
            pageBuilder: (context, state) => fadeTabPage(const AdminSupportScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) => fadeTabPage(const AdminSettingsScreen(), key: state.pageKey),
          ),
          GoRoute(
            path: '/admin/promos',
            pageBuilder: (context, state) => fadeTabPage(const AdminPromoCodesScreen(), key: state.pageKey),
          ),
        ],
      ),
    ],
  );
});
