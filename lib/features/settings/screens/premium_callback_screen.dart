import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class PremiumCallbackScreen extends ConsumerStatefulWidget {
  final String? sessionId;

  const PremiumCallbackScreen({super.key, this.sessionId});

  @override
  ConsumerState<PremiumCallbackScreen> createState() => _PremiumCallbackScreenState();
}

class _PremiumCallbackScreenState extends ConsumerState<PremiumCallbackScreen> {
  bool _isLoading = true;
  String? _error;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _verifySession();
  }

  Future<void> _verifySession() async {
    final sessionId = widget.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid payment session identifier.';
      });
      return;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-api',
        body: {
          'action': 'verify_stripe_session',
          'sessionId': sessionId,
        },
      );

      if (response.status == 200) {
        // Sync profile data to update premium state locally
        await ref.read(authProvider.notifier).syncProfileData();
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to verify payment session: Status ${response.status}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Verification failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(color: AppColors.primaryNeon),
                const SizedBox(height: 24),
                const Text(
                  'Verifying Payment...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confirming your transaction with Stripe. Please do not close or reload this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ] else if (_isSuccess) ...[
                const Icon(Icons.stars_rounded, color: AppColors.primaryNeon, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Upgrade Successful!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Congratulations! You are now an EditFlow Pro member. Your limits have been unlocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNeon,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.go('/dashboard'),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Verification Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'An unexpected error occurred.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.go('/dashboard'),
                  child: const Text(
                    'Back to Dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
