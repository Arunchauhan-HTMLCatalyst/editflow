import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.back, color: isDark ? AppColors.textPrimary : Color(0xFF18181B)),
          onPressed: () => context.go('/login'),
        ),
        middle: Text('Reset Password', style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
        )),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.xxl),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(CupertinoIcons.lock_rotation_open, size: 32, color: AppColors.primary),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Forgot your password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.textSecondary : Color(0xFF52525B),
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              if (_sent)
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Reset link sent! Check your email.',
                    style: TextStyle(color: AppColors.success, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252535) : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.border : Color(0xFFE4E4E7),
                      width: 0.5,
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _emailController,
                    placeholder: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    padding: EdgeInsets.all(AppSpacing.sm),
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : Color(0xFF18181B),
                      fontSize: 16,
                    ),
                    placeholderStyle: TextStyle(
                      color: isDark ? AppColors.textMuted : Color(0xFF71717A),
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                GestureDetector(
                  onTap: isLoading ? null : _sendReset,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: isLoading
                          ? CupertinoActivityIndicator(radius: 10, color: CupertinoColors.white)
                          : Text(
                              'Send Reset Link',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.xxl),
              CupertinoButton(
                child: Text(
                  'Back to Sign In',
                  style: TextStyle(fontSize: 15, color: AppColors.primary),
                ),
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendReset() {
    ref.read(authProvider.notifier).resetPassword(_emailController.text.trim());
    setState(() => _sent = true);
  }
}
