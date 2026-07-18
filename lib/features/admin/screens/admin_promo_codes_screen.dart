import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminPromoCodesScreen extends ConsumerStatefulWidget {
  const AdminPromoCodesScreen({super.key});

  @override
  ConsumerState<AdminPromoCodesScreen> createState() => _AdminPromoCodesScreenState();
}

class _AdminPromoCodesScreenState extends ConsumerState<AdminPromoCodesScreen> {
  bool _isLoading = false;

  Future<void> _createPromoCode() async {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final maxUsesController = TextEditingController(text: '1');
    final durationController = TextEditingController(text: '30');
    DateTime? selectedExpiry;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border, width: 0.8),
            ),
            title: const Text(
              'Generate Promo Code',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Promo Code Text',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        hintText: 'e.g. FREE30DAYS',
                        border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Promo code is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: durationController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Duration (Days)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        hintText: '30',
                        border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Duration is required';
                        }
                        final num = int.tryParse(val);
                        if (num == null || num <= 0) {
                          return 'Duration must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: maxUsesController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Max Allowed Uses (leave empty for unlimited)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        hintText: '1',
                        border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedExpiry == null
                            ? 'No Expiry Date Set'
                            : 'Expires: ${DateFormat('yyyy-MM-dd').format(selectedExpiry!)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month, color: AppColors.primaryNeon),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppColors.primaryNeon,
                                    onPrimary: Colors.white,
                                    surface: AppColors.card,
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedExpiry = DateTime(date.year, date.month, date.day, 23, 59, 59);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNeon,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Generate'),
              ),
            ],
          );
        },
      ),
    );

    final code = codeController.text.trim();
    if (code.isNotEmpty) {
      final maxUses = int.tryParse(maxUsesController.text);
      final durationDays = int.tryParse(durationController.text) ?? 30;

      setState(() => _isLoading = true);
      try {
        await AdminService.invokeAdminAction('create_promo_code', {
          'code': code,
          'maxUses': maxUses,
          'durationDays': durationDays,
          'expiresAt': selectedExpiry?.toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Promo Code "$code" successfully generated!'),
            ),
          );
          ref.invalidate(adminPromoCodesProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Failed to generate code: $e'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePromoStatus(String id, bool currentStatus) async {
    setState(() => _isLoading = true);
    try {
      await AdminService.invokeAdminAction('toggle_promo_code', {
        'promoId': id,
        'isActive': !currentStatus,
      });
      ref.invalidate(adminPromoCodesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePromoCode(String id, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Promo Code?'),
        content: Text('Are you sure you want to delete promo code "$code"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await AdminService.invokeAdminAction('delete_promo_code', {'promoId': id});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Promo code deleted.')),
          );
          ref.invalidate(adminPromoCodesProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final promosAsync = ref.watch(adminPromoCodesProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PROMO CODES MANAGEMENT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNeon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _createPromoCode,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: promosAsync.when(
                data: (promos) {
                  if (promos.isEmpty) {
                    return const Center(
                      child: Text(
                        'No promo codes created yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Container(
                        width: isDesktop ? MediaQuery.of(context).size.width - 260 : 800,
                        padding: const EdgeInsets.all(16),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            cardColor: AppColors.card,
                            dividerColor: AppColors.border,
                          ),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(AppColors.card),
                            border: TableBorder.all(color: AppColors.border, width: 0.5, borderRadius: BorderRadius.circular(8)),
                            columns: const [
                              DataColumn(label: Text('Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Duration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Uses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Expires At', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Created At', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ],
                            rows: promos.map((p) {
                              final id = p['id'] as String;
                              final code = p['code'] as String;
                              final isActive = p['is_active'] as bool;
                              final maxUses = p['max_uses'] as int?;
                              final usedCount = p['used_count'] as int;
                              final duration = p['duration_days'] as int;
                              final expiresAtStr = p['expires_at'] as String?;
                              final createdAtStr = p['created_at'] as String;

                              final expiresAt = expiresAtStr != null ? DateTime.parse(expiresAtStr) : null;
                              final createdAt = DateTime.parse(createdAtStr);

                              final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
                              final isMaxedOut = maxUses != null && usedCount >= maxUses;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('$duration Days', style: const TextStyle(color: Colors.white))),
                                  DataCell(Text('$usedCount / ${maxUses ?? "∞"}', style: const TextStyle(color: Colors.white))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isExpired || isMaxedOut
                                            ? AppColors.error.withValues(alpha: 0.15)
                                            : isActive
                                                ? AppColors.success.withValues(alpha: 0.15)
                                                : AppColors.textMuted.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isExpired
                                            ? 'Expired'
                                            : isMaxedOut
                                                ? 'Maxed Out'
                                                : isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                        style: TextStyle(
                                          color: isExpired || isMaxedOut
                                              ? AppColors.error
                                              : isActive
                                                  ? AppColors.success
                                                  : AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(
                                    expiresAt != null ? DateFormat('yyyy-MM-dd').format(expiresAt) : 'Never',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  )),
                                  DataCell(Text(
                                    DateFormat('yyyy-MM-dd').format(createdAt),
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  )),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isActive ? Icons.visibility : Icons.visibility_off,
                                            color: isActive ? AppColors.primaryNeon : AppColors.textMuted,
                                            size: 18,
                                          ),
                                          onPressed: _isLoading ? null : () => _togglePromoStatus(id, isActive),
                                          tooltip: isActive ? 'Deactivate' : 'Activate',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                                          onPressed: _isLoading ? null : () => _deletePromoCode(id, code),
                                          tooltip: 'Delete Code',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
                error: (err, _) => Center(child: Text('Error loading codes: $err', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ],
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryNeon),
              ),
            ),
          ),
      ],
    );
  }
}
