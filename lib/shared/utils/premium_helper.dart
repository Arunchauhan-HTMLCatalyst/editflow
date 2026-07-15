import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (authState.isPro) return true; // Upgrade checks ignored for Pro users

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
    if (authState.isPro) return true; // Upgrade checks ignored for Pro users

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
                Navigator.pop(context); // Dismiss dialog
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                  'Choose Premium Plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock unlimited clients, projects, reviews and and more premium features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                
                // Monthly Plan Option
                _buildPlanCard(
                  title: 'Monthly Subscription',
                  price: '₹99 / month',
                  description: 'Best for short-term projects & freelancers.',
                  checkoutUrl: 'https://buy.stripe.com/test_55y333333333333333', // Replace with Stripe Link
                  context: context,
                ),
                const SizedBox(height: 12),

                // Yearly Plan Option
                _buildPlanCard(
                  title: 'Yearly Subscription',
                  price: '₹999 / year',
                  description: 'Save 15% overall. Best for professional freelancers.',
                  checkoutUrl: 'https://buy.stripe.com/test_77y444444444444444', // Replace with Stripe Link
                  context: context,
                  isPopular: true,
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildPlanCard({
    required String title,
    required String price,
    required String description,
    required String checkoutUrl,
    required BuildContext context,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? AppColors.primaryNeon : AppColors.border,
          width: isPopular ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNeon.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(color: AppColors.primaryNeon, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPopular ? AppColors.primaryNeon : AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              Navigator.pop(context); // Close bottom sheet
              // Launch Stripe Checkout link in external browser
              // Note: You can customize return url config in Stripe Dashboard
              // https://editflow.acsoft.online/app/#/premium-callback?session_id={CHECKOUT_SESSION_ID}
              // For testing locally we can simulate or open the link
              // To launch url we can use standard url_launcher, but since we are inside flutter we can do simple JS/window.open for web or let the user follow redirect.
              // Let's print or trigger open link
              _launchUrl(checkoutUrl);
            },
            child: Text(
              price,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static void _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('[PremiumHelper] Failed to launch url: $e');
      }
    }
  }
}
