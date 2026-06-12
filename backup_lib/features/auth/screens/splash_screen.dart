import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (SupabaseService.currentUser != null) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      context.go('/dashboard');
      return;
    }

    StreamSubscription? sub;
    sub = SupabaseService.instance.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        sub?.cancel();
        context.go('/dashboard');
      }
    });

    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    sub.cancel();

    if (SupabaseService.currentUser != null) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return CupertinoPageScaffold(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0B0B14),
                    const Color(0xFF11101A),
                    const Color(0xFF1A1028),
                  ]
                : [
                    const Color(0xFFF8F9FC),
                    const Color(0xFFF3F0FF),
                    const Color(0xFFEDE9FE),
                  ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.pencil_ellipsis_rectangle,
                      color: CupertinoColors.white,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Text(
                    'EditFlow',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF18181B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Freelance Project Management',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF52525B),
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxxl),
                  CupertinoActivityIndicator(radius: 10),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Getting things ready...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textMuted
                          : const Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
