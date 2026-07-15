import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Announcement state
  bool _announcementVisible = false;
  final TextEditingController _announcementTextController = TextEditingController();

  // Maintenance state
  bool _maintenanceEnabled = false;
  final TextEditingController _maintenanceMessageController = TextEditingController();

  // Support state
  final TextEditingController _supportEmailController = TextEditingController();

  // UPI configuration state
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _bankingNameController = TextEditingController();

  bool _isSaving = false;
  bool _isLoaded = false;

  void _loadSettings(List<Map<String, dynamic>> settingsList) {
    if (_isLoaded) return;

    for (final setting in settingsList) {
      final key = setting['key'];
      final value = setting['value'] as Map<String, dynamic>? ?? {};

      if (key == 'announcement') {
        _announcementVisible = value['visible'] as bool? ?? false;
        _announcementTextController.text = value['text'] as String? ?? '';
      } else if (key == 'maintenance') {
        _maintenanceEnabled = value['enabled'] as bool? ?? false;
        _maintenanceMessageController.text = value['message'] as String? ?? '';
      } else if (key == 'support') {
        _supportEmailController.text = value['email'] as String? ?? '';
      } else if (key == 'upi') {
        _upiIdController.text = value['upi_id'] as String? ?? 'editflow@upi';
        _bankingNameController.text = value['banking_name'] as String? ?? 'EditFlow Admin';
      }
    }

    _isLoaded = true;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await AdminService.invokeAdminAction('update_settings', {
        'settingsList': [
          {
            'key': 'announcement',
            'value': {
              'text': _announcementTextController.text.trim(),
              'visible': _announcementVisible,
            }
          },
          {
            'key': 'maintenance',
            'value': {
              'message': _maintenanceMessageController.text.trim(),
              'enabled': _maintenanceEnabled,
            }
          },
          {
            'key': 'support',
            'value': {
              'email': _supportEmailController.text.trim(),
            }
          },
          {
            'key': 'upi',
            'value': {
              'upi_id': _upiIdController.text.trim(),
              'banking_name': _bankingNameController.text.trim(),
            }
          }
        ]
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Global system settings updated successfully!')),
        );
        _isLoaded = false;
        ref.invalidate(adminSettingsProvider);
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _announcementTextController.dispose();
    _maintenanceMessageController.dispose();
    _supportEmailController.dispose();
    _upiIdController.dispose();
    _bankingNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading settings: $e', style: const TextStyle(color: AppColors.textSecondary))),
      data: (settings) {
        _loadSettings(settings);

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Announcement Banner Settings Card
                _buildCard(
                  title: 'SYSTEM ANNOUNCEMENT BANNER',
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _announcementVisible,
                        title: const Text('Show Banner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: const Text('Toggles visibility of the banner for all users.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        activeColor: AppColors.primaryNeon,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setState(() {
                            _announcementVisible = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _announcementTextController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Announcement Text',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          hintText: 'e.g. Welcome to EditFlow v2.0! Check out shareable review links.',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Maintenance Mode Card
                _buildCard(
                  title: 'MAINTENANCE MODE STATUS',
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _maintenanceEnabled,
                        title: const Text('Enable Maintenance Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: const Text('If enabled, standard users are locked out of the app.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        activeColor: Colors.redAccent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setState(() {
                            _maintenanceEnabled = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maintenanceMessageController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Message',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Support Contact
                _buildCard(
                  title: 'SYSTEM SUPPORT CONTACTS',
                  child: TextFormField(
                    controller: _supportEmailController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Support Contact Email',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Support email is required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 4. UPI QR Settings
                _buildCard(
                  title: 'UPI PAYMENT CONFIGURATION',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _upiIdController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Admin UPI ID (for QR Code)',
                          hintText: 'e.g. yourname@upi',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'UPI ID is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankingNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Banking Payee Name',
                          hintText: 'e.g. AC Soft Solutions',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Banking payee name is required';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 14),
                    label: const Text('Save Configuration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
