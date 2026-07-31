import 'dart:async';
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

  // Support state (hidden but kept in state for database compatibility)
  final TextEditingController _supportEmailController = TextEditingController();

  bool _isSaving = false;
  bool _isLoaded = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _announcementTextController.addListener(_onTextChanged);
    _maintenanceMessageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_isLoaded || _isSaving) return;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _saveSettings();
      }
    });
  }

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
        _supportEmailController.text = value['email'] as String? ?? 'editflow@acsoft.online';
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
              'email': _supportEmailController.text.isNotEmpty ? _supportEmailController.text.trim() : 'editflow@acsoft.online',
            }
          }
        ]
      });

      if (mounted) {
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
    _debounceTimer?.cancel();
    _announcementTextController.removeListener(_onTextChanged);
    _maintenanceMessageController.removeListener(_onTextChanged);
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
                // Live sync indicator at the top
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isSaving ? Colors.orangeAccent : const Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color: _isSaving 
                                  ? Colors.orangeAccent.withValues(alpha: 0.4) 
                                  : const Color(0xFF10B981).withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSaving ? 'Syncing changes live...' : 'Live configurations active (Auto-saved)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isSaving ? Colors.orangeAccent : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),

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
                            onChanged: (val) {
                              setState(() => _announcementVisible = val);
                              _saveSettings();
                            },
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
                            onChanged: (val) {
                              setState(() => _maintenanceEnabled = val);
                              _saveSettings();
                            },
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
                const SizedBox(height: 32),
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
