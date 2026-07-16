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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
      error: (err, stack) => Center(child: Text('Error loading settings: $err', style: const TextStyle(color: Colors.white))),
      data: (settingsList) {
        _loadSettings(settingsList);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Form(
            key: _formKey,
            child: ListView(
              children: [
                // 1. Announcement Banner Settings
                _buildCard(
                  title: 'SYSTEM ANNOUNCEMENT BANNER',
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Show Announcement Banner', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Switch(
                            value: _announcementVisible,
                            onChanged: (val) => setState(() => _announcementVisible = val),
                            activeColor: AppColors.primaryNeon,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _announcementTextController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Announcement Text',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Maintenance Mode settings
                _buildCard(
                  title: 'MAINTENANCE MODE CONFIGURATION',
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Enable Maintenance Mode', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Switch(
                            value: _maintenanceEnabled,
                            onChanged: (val) => setState(() => _maintenanceEnabled = val),
                            activeColor: Colors.redAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maintenanceMessageController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Overlay Message',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Support Contact Settings
                _buildCard(
                  title: 'SUPPORT CONTACT SETUP',
                  child: Column(
                    children: [
                      TextFormField(
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
