import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class _UpiPaymentSheet extends StatefulWidget {
  const _UpiPaymentSheet();

  @override
  State<_UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends State<_UpiPaymentSheet> {
  String _upiId = 'editflow@upi';
  bool _isLoadingUpi = true;
  String _selectedPlan = 'monthly'; // 'monthly' or 'yearly'
  final TextEditingController _utrController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchUpiId();
  }

  Future<void> _fetchUpiId() async {
    try {
      final res = await Supabase.instance.client
          .from('system_settings')
          .select('value')
          .eq('key', 'upi')
          .maybeSingle();

      if (res != null && res['value'] is Map) {
        final val = res['value'] as Map;
        if (mounted) {
          setState(() {
            _upiId = val['upi_id'] as String? ?? 'editflow@upi';
            _isLoadingUpi = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _upiId = 'editflow@upi';
            _isLoadingUpi = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[PremiumHelper] Failed to load UPI settings: $e');
      if (mounted) {
        setState(() {
          _upiId = 'editflow@upi';
          _isLoadingUpi = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final planLabel = _selectedPlan == 'monthly' ? 'Monthly' : 'Yearly';
      final amountLabel = _selectedPlan == 'monthly' ? '₹99' : '₹999';

      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': user.id,
        'subject': '[Premium Upgrade Request]',
        'description': 'Plan: $planLabel\nAmount: $amountLabel\nUTR: ${_utrController.text.trim()}',
        'category': 'billing',
        'status': 'open',
      });

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Upgrade request submitted! Admin will verify and activate your Premium subscription shortly.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to submit request: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double amount = _selectedPlan == 'monthly' ? 99 : 999;
    final String upiUrl = 'upi://pay?pa=$_upiId&pn=EditFlow&tn=Pro_Upgrade_${_selectedPlan.toUpperCase()}&am=$amount&cu=INR';

    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull indicator bar
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
              const SizedBox(height: 24),

              if (_isLoadingUpi)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30.0),
                    child: CircularProgressIndicator(color: AppColors.primaryNeon),
                  ),
                )
              else ...[
                // QR Code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryNeon.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: upiUrl,
                      version: QrVersions.auto,
                      size: 160.0,
                      gapless: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan the QR code with GPay, PhonePe, or Paytm to pay',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),

                // Payee Details Copy Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payee UPI ID', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            Text(_upiId, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppColors.primaryNeon, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _upiId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UPI ID copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Verification Input Form
                const Text(
                  'SUBMIT TRANSACTION DETAILS',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _utrController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '12-digit UPI Reference No. / UTR',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g. 340984859261',
                    border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Reference No / UTR is required';
                    if (val.trim().length != 12) return 'Must be exactly 12 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

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
                      : const Text('Submit Verification Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
