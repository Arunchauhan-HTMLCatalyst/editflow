import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _messageType = 'announcement'; // 'announcement', 'update', 'custom'
  String _targetType = 'all'; // 'all', 'selected', 'admins', 'non_admins'
  final List<String> _selectedUserIds = [];

  bool _isSending = false;

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetType == 'selected' && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user to target.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final res = await AdminService.invokeAdminAction('send_broadcast', {
        'messageType': _messageType,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'targetType': _targetType,
        'selectedUserIds': _selectedUserIds,
      });

      final count = res['count'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully broadcasted notification to $count user(s)!')),
        );
        _titleController.clear();
        _descController.clear();
        setState(() {
          _selectedUserIds.clear();
          _isSending = false;
        });
        ref.invalidate(adminStatsProvider); // refresh activity stream
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send broadcast: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(''));
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: composer form
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COMPOSE MESSAGE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),

                        // Message Type Select
                        DropdownButtonFormField<String>(
                          value: _messageType,
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Message Category',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'announcement', child: Text('Announcement (General)')),
                            DropdownMenuItem(value: 'update', child: Text('System Update')),
                            DropdownMenuItem(value: 'custom', child: Text('Custom Message')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _messageType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Title
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Message Title',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descController,
                          maxLines: 5,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Message Content',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                            alignLabelWithHint: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Content is required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Target Selector
                        DropdownButtonFormField<String>(
                          value: _targetType,
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Target Audience',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Users')),
                            DropdownMenuItem(value: 'admins', child: Text('Admins Only')),
                            DropdownMenuItem(value: 'non_admins', child: Text('Non-Admins (Standard Users)')),
                            DropdownMenuItem(value: 'selected', child: Text('Selected Individual Users')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _targetType = val;
                                _selectedUserIds.clear();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendNotification,
                            icon: _isSending
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded, size: 14),
                            label: const Text('Broadcast Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                ),

                // Right side: User Multi-Selector (only when TargetType is 'selected')
                if (_targetType == 'selected') ...[
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 480,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECT RECIPIENTS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: usersAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Text('Error: $e'),
                              data: (users) {
                                return ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, idx) {
                                    final u = users[idx];
                                    final uid = u['id'] as String;
                                    final name = u['full_name'] as String? ?? 'User';
                                    final email = u['email'] as String? ?? '';
                                    final isSelected = _selectedUserIds.contains(uid);

                                    return CheckboxListTile(
                                      value: isSelected,
                                      title: Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                      subtitle: Text(email, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                      activeColor: AppColors.primaryNeon,
                                      checkColor: Colors.white,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedUserIds.add(uid);
                                          } else {
                                            _selectedUserIds.remove(uid);
                                          }
                                        });
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
