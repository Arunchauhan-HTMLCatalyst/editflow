import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
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
import 'features/projects/screens/add_project_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/dashboard/screens/notification_center_screen.dart';
import 'features/dashboard/screens/client_reviews_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'app_shell.dart';
import 'core/theme/app_transitions.dart';

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
      if (loc.contains('io.supabase.flutter') ||
          loc.contains('/callback?code=')) {
        return '/splash';
      }

      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/splash';

      final authState = ref.read(authProvider);
      final isUnauthenticated = authState.status == AuthStatus.unauthenticated;
      final isAuthenticated = authState.status == AuthStatus.authenticated;

      if (isUnauthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute && loc != '/splash') {
        return '/dashboard';
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
        pageBuilder: (context, state) => slideUpPage(const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => slideUpPage(const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => slideUpPage(const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => slideUpPage(const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => settingsPage(const SettingsScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => slidePushPage(const NotificationCenterScreen()),
      ),

      // Sheet-style creation screens → slide up from bottom
      GoRoute(
        path: '/projects/add',
        pageBuilder: (context, state) {
          final clientId = state.uri.queryParameters['clientId'];
          final freelancerId = state.uri.queryParameters['freelancerId'];
          final freelancerName = state.uri.queryParameters['freelancerName'];
          return slideUpPage(AddProjectScreen(
            preselectedClientId: clientId,
            preselectedFreelancerId: freelancerId,
            preselectedFreelancerName: freelancerName,
          ));
        },
      ),
      GoRoute(
        path: '/add-client',
        pageBuilder: (context, state) => slideUpPage(const AddClientScreen()),
      ),

      // Detail screens → slide in from right
      GoRoute(
        path: '/clients/:id',
        pageBuilder: (context, state) => slidePushPage(ClientDetailScreen(
          clientId: state.pathParameters['id']!,
        )),
      ),
      GoRoute(
        path: '/freelancers/:id',
        pageBuilder: (context, state) => slidePushPage(FreelancerDetailScreen(
          freelancerId: state.pathParameters['id']!,
        )),
      ),
      GoRoute(
        path: '/projects/:id',
        pageBuilder: (context, state) => slidePushPage(ProjectDetailScreen(
          projectId: state.pathParameters['id']!,
        )),
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
          ));
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
            pageBuilder: (context, state) => fadeTabPage(const DashboardScreen()),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => fadeTabPage(const ClientsScreen()),
          ),
          GoRoute(
            path: '/reviews',
            pageBuilder: (context, state) => fadeTabPage(const ClientReviewsScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => fadeTabPage(const CalendarScreen()),
          ),
          GoRoute(
            path: '/payments',
            pageBuilder: (context, state) => fadeTabPage(const PaymentsScreen()),
          ),
        ],
      ),
    ],
  );
});
