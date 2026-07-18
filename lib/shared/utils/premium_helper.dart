import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/clients/providers/client_provider.dart';
import '../../features/projects/providers/project_provider.dart';

class PremiumHelper {
  PremiumHelper._();

  static const int freeClientLimit = 5;
  static const int freeProjectLimit = 10;

  static bool checkClientLimit(WidgetRef ref, BuildContext context) {
    final authState = ref.read(authProvider);
    if (authState.isPro) return true;

    final clientCount = ref.read(clientProvider).valueOrNull?.length ?? 0;
    if (clientCount >= freeClientLimit) {
      showPremiumLimitDialog(
        context,
        'Free Limit reached. Need to Upgrade to Premium to continue using editflow (Maximum $freeClientLimit clients on Free plan).',
      );
      return false;
    }
    return true;
  }

  static bool checkProjectLimit(WidgetRef ref, BuildContext context) {
    final authState = ref.read(authProvider);
    if (authState.isPro) return true;

    final projectCount = ref.read(projectProvider).valueOrNull?.length ?? 0;
    if (projectCount >= freeProjectLimit) {
      showPremiumLimitDialog(
        context,
        'Free Limit reached. Need to Upgrade to Premium to continue using editflow (Maximum $freeProjectLimit projects on Free plan).',
      );
      return false;
    }
    return true;
  }

  static void showPremiumLimitDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          title: Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.primaryNeon, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Premium Upgrade',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                showUpgradeOptionsModal(context);
              },
              child: const Text('Upgrade Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static void showUpgradeOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const _UpiPaymentSheet();
      },
    );
  }
}

class _UpiPaymentSheet extends ConsumerStatefulWidget {
  const _UpiPaymentSheet();

  @override
  ConsumerState<_UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends ConsumerState<_UpiPaymentSheet> {
  String _selectedPlan = 'monthly';
  bool _isSubmitting = false;
  String? _errorMessage;

  final _promoController = TextEditingController();
  bool _isRedeeming = false;
  String? _promoFeedback;
  bool _promoSuccess = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _redeemPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isRedeeming = true;
      _promoFeedback = null;
      _promoSuccess = false;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Call database RPC function
      final response = await Supabase.instance.client.rpc(
        'redeem_promo_code',
        params: {
          'p_user_id': user.id,
          'p_code': code,
        },
      );

      if (response == null) {
        throw Exception('Redemption failed (no response)');
      }

      final res = Map<String, dynamic>.from(response as Map);
      final success = res['success'] as bool? ?? false;
      final message = res['message'] as String? ?? 'Redemption failed';

      if (!success) {
        throw Exception(message);
      }

      // Success! Invalidate auth provider to refresh user profile premium status
      ref.invalidate(authProvider);

      setState(() {
        _promoSuccess = true;
        _promoFeedback = 'Code redeemed successfully! Extended Premium active.';
        _promoController.clear();
      });
    } catch (e) {
      setState(() {
        _promoSuccess = false;
        _promoFeedback = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isRedeeming = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Invoke Supabase Edge Function to get Razorpay checkout link
      final response = await Supabase.instance.client.functions.invoke(
        'razorpay/create-link',
        body: {'planType': _selectedPlan},
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['error'] : 'Failed to initiate payment';
        throw Exception(errorMsg);
      }

      final shortUrl = response.data['short_url'] as String?;
      if (shortUrl == null || shortUrl.isEmpty) {
        throw Exception('Invalid payment link returned');
      }

      final uri = Uri.parse(shortUrl);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          Navigator.pop(context); // Close bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                'Opening checkout page. Once payment is completed, your account will be upgraded instantly!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          );
        }
      } catch (e) {
        throw Exception('Could not open payment page: $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upgrade to Premium',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Unlock unlimited clients, projects, reviews and cloud benefits.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Segmented Toggle for Plan Selection
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlan = 'monthly'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedPlan == 'monthly' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: const Center(
                          child: Text(
                            'Monthly — ₹99',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlan = 'yearly'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedPlan == 'yearly' ? AppColors.primaryNeon : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: const Center(
                          child: Text(
                            'Yearly — ₹999',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Plan comparison card details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPlan == 'yearly'
                      ? AppColors.primaryNeon.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedPlan == 'yearly' ? 'PRO YEARLY PLAN (RECOMMENDED)' : 'PRO MONTHLY PLAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _selectedPlan == 'yearly' ? AppColors.primaryNeon : AppColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (_selectedPlan == 'yearly')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'SAVE 16%',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNeon,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _selectedPlan == 'yearly' ? '₹999' : '₹99',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedPlan == 'yearly' ? '/year' : '/month',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedPlan == 'yearly'
                        ? 'Equivalent to just ₹83/month. Charged yearly.'
                        : 'Charged monthly. Standard tier benefits.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  
                  _buildFeatureItem('Unlimited Clients & Projects (Free: max 5/10)', true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'AUTOMATED CHECKOUT',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be redirected to Razorpay to complete your purchase securely. Once the payment is complete, your Premium subscription will be instantly activated automatically.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Promo Code Section
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 13,
                        color: AppColors.primaryNeon,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'PROMO CODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: 'Enter code (e.g. FREE30DAYS)',
                              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isRedeeming ? null : _redeemPromoCode,
                                child: Ink(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary, AppColors.primaryNeon],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Container(
                                    height: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.center,
                                    child: _isRedeeming
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Apply',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_promoFeedback != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            _promoSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                            size: 14,
                            color: _promoSuccess ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _promoFeedback!,
                              style: TextStyle(
                                color: _promoSuccess ? AppColors.success : AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedPlan == 'monthly' ? AppColors.primary : AppColors.primaryNeon,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSubmitting ? null : _submitRequest,
              child: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
            size: 14,
            color: active ? AppColors.primaryNeon : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: active ? Colors.white : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
