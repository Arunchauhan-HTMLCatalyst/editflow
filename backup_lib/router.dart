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
import 'features/payments/screens/payments_screen.dart';
import 'features/projects/screens/project_detail_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'app_shell.dart';
import 'core/theme/app_transitions.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.uri.toString();
      if (loc.contains('io.supabase.flutter') ||
          loc.contains('/callback?code=')) {
        return '/splash';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
    routes: [
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
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => slideUpPage(const DashboardScreen()),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => slideUpPage(const ClientsScreen()),
          ),
          GoRoute(
            path: '/clients/:id',
            pageBuilder: (context, state) => slideUpPage(ClientDetailScreen(
              clientId: state.pathParameters['id']!,
            )),
          ),
          GoRoute(
            path: '/projects/:id',
            pageBuilder: (context, state) => slideUpPage(ProjectDetailScreen(
              projectId: state.pathParameters['id']!,
            )),
          ),
          GoRoute(
            path: '/add-client',
            pageBuilder: (context, state) => slideUpPage(const AddClientScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => slideUpPage(const CalendarScreen()),
          ),
          GoRoute(
            path: '/payments',
            pageBuilder: (context, state) => slideUpPage(const PaymentsScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => slideUpPage(const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
