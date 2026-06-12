import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return CupertinoPageScaffold(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F0F1A), const Color(0xFF1A1028)]
                : [const Color(0xFFF8F9FC), const Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.pencil_ellipsis_rectangle,
                      color: CupertinoColors.white,
                      size: 36,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Text(
                    'EditFlow',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Freelance Project Management',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.textSecondary : Color(0xFF52525B),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxxl * 2),

                  if (authState.error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        authState.error!,
                        style: TextStyle(color: AppColors.error, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  _Field(
                    controller: _emailController,
                    placeholder: 'Email',
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: AppSpacing.md),
                  _Field(
                    controller: _passwordController,
                    placeholder: 'Password',
                    isDark: isDark,
                    obscureText: !_showPassword,
                    suffix: CupertinoButton(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        _showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                        size: 18,
                        color: isDark ? AppColors.textMuted : Color(0xFF71717A),
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            ref.read(authProvider.notifier).signIn(
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                          },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isLoading
                            ? CupertinoActivityIndicator(radius: 10, color: CupertinoColors.white)
                            : Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: () => context.push('/forgot-password'),
                  ),

                  SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: Container(height: 0.5, color: isDark ? AppColors.border : Color(0xFFE4E4E7))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text(
                          'or',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondary : Color(0xFF52525B),
                          ),
                        ),
                      ),
                      Expanded(child: Container(height: 0.5, color: isDark ? AppColors.border : Color(0xFFE4E4E7))),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),

                  GestureDetector(
                    onTap: isLoading ? null : () => ref.read(authProvider.notifier).signInWithGoogle(),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.border : Color(0xFFE4E4E7),
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.textSecondary : Color(0xFF52525B),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        onPressed: () => context.push('/register'),
                      ),
                    ],
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool isDark;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.placeholder,
    required this.isDark,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252535) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.border : Color(0xFFE4E4E7),
          width: 0.5,
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        obscureText: obscureText,
        padding: EdgeInsets.all(AppSpacing.sm),
        suffix: suffix,
        style: TextStyle(
          color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
          fontSize: 16,
        ),
        placeholderStyle: TextStyle(
          color: isDark ? AppColors.textMuted : Color(0xFF71717A),
          fontSize: 16,
        ),
      ),
    );
  }
}
