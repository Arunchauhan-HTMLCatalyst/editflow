import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../providers/project_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../../settings/providers/settings_provider.dart';

class AddProjectScreen extends ConsumerStatefulWidget {
  final String? preselectedClientId;
  final String? preselectedFreelancerId;
  final String? preselectedFreelancerName;
  const AddProjectScreen({
    super.key,
    this.preselectedClientId,
    this.preselectedFreelancerId,
    this.preselectedFreelancerName,
  });

  @override
  ConsumerState<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends ConsumerState<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _receivedController = TextEditingController();
  final _deadlineController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedClientId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.preselectedClientId;
    if (_selectedClientId == null && widget.preselectedFreelancerId == null) {
      final clients = ref.read(safeClientsProvider);
      if (clients.isNotEmpty) {
        _selectedClientId = clients.first.id;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _receivedController.dispose();
    _deadlineController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isClient = ref.read(settingsProvider).isClientMode;
    if (widget.preselectedFreelancerId == null && _selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isClient ? 'Please select a freelancer' : 'Please select a client')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authState = ref.read(authProvider);
      final currentUserId = authState.user?.id ?? SupabaseService.userId;
      final clients = ref.read(safeClientsProvider);

      String targetUserId = currentUserId;
      String? targetClientId = _selectedClientId;

      if (isClient) {
        if (widget.preselectedFreelancerId != null) {
          targetUserId = widget.preselectedFreelancerId!;
          
          // Look up if a client record already exists for this freelancer in Supabase
          final existingClient = await SupabaseService.instance
              .from('clients')
              .select('id')
              .eq('user_id', targetUserId)
              .eq('client_user_id', currentUserId)
              .maybeSingle();

          if (existingClient != null) {
            targetClientId = existingClient['id'] as String;
          } else {
            // Self-healing: create the missing connection link in the database!
            final profile = await SupabaseService.instance
                .from('profiles')
                .select('full_name')
                .eq('id', currentUserId)
                .maybeSingle();
            final clientName = profile?['full_name'] as String? ?? 'Client';

            final newClientId = await SupabaseService.instance
                .rpc('create_client_connection', params: {
                  'freelancer_id': targetUserId,
                  'client_name': clientName,
                });
            targetClientId = newClientId as String;
            
            // Refresh clients in the background
            ref.read(clientProvider.notifier).refresh();
          }
        } else {
          final selectedClient = clients.firstWhere((c) => c.id == _selectedClientId);
          targetUserId = selectedClient.userId;
          targetClientId = _selectedClientId;
        }
      }

      final project = Project(
        id: '',
        userId: targetUserId,
        clientId: targetClientId!,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        receivedAmount: isClient ? 0.0 : (double.tryParse(_receivedController.text.trim()) ?? 0.0),
        deadline: _deadlineController.text.trim().isNotEmpty
            ? DateTime.tryParse(_deadlineController.text.trim())
            : null,
        status: ProjectStatus.yetToStart,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(projectProvider.notifier).addProject(project);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project created successfully')),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create project: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clients = ref.watch(safeClientsProvider);
    final currency = ref.watch(currencyProvider);
    final isClient = ref.watch(settingsProvider).isClientMode;

    bool isPreselectedMissing = false;
    if (isClient && widget.preselectedClientId != null && clients.isNotEmpty) {
      final hasPreselected = clients.any((c) => c.id == widget.preselectedClientId);
      if (!hasPreselected) {
        isPreselectedMissing = true;
      }
    }

    // Dynamically resolve and auto-select the chosen client/freelancer ID once loaded
    if (clients.isNotEmpty && !isPreselectedMissing) {
      final hasSelected = clients.any((c) => c.id == _selectedClientId);
      if (!hasSelected) {
        if (widget.preselectedClientId != null && clients.any((c) => c.id == widget.preselectedClientId)) {
          _selectedClientId = widget.preselectedClientId;
        } else {
          _selectedClientId = clients.first.id;
        }
      }
    } else if (isPreselectedMissing) {
      _selectedClientId = null;
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : CupertinoColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.back,
                size: 18,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => context.pop()),
          ),
        ),
        title: Text(
          isClient ? 'Assign Project' : 'Add Project',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (clients.isNotEmpty)
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: isPreselectedMissing ? null : _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
        ],
      ),
      body: SafeArea(
        child: clients.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        isClient ? 'No Freelancers Found' : 'No Clients Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isClient
                            ? 'You need to be connected to a freelancer to assign a project.'
                            : 'You need to create a client before adding a project.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!isClient) ...[
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.push('/add-client'),
                          child: const Text('Add Client'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.preselectedFreelancerId != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ASSIGNED FREELANCER',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.preselectedFreelancerName ?? 'Freelancer',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedClientId),
                          initialValue: _selectedClientId,
                          decoration: InputDecoration(
                            labelText: isClient ? 'Freelancer *' : 'Client *',
                          ),
                          dropdownColor: isDark ? AppColors.surface : Colors.white,
                          items: clients.map((c) {
                            final displayName = isClient
                                ? (c.notes != null && c.notes!.isNotEmpty && c.notes!.toLowerCase() != 'n/a' ? c.notes! : 'Freelancer')
                                : (c.company != null && c.company!.isNotEmpty
                                    ? '${c.name} (${c.company})'
                                    : c.name);
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                  fontSize: 14.5,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedClientId = value);
                          },
                          validator: (value) => value == null
                              ? (isClient ? 'Freelancer is required' : 'Client is required')
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Project Name *',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      if (isClient)
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: 'Budget',
                            prefixText: '${currency.symbol} ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: InputDecoration(
                                  labelText: 'Budget',
                                  prefixText: '${currency.symbol} ',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _receivedController,
                                decoration: InputDecoration(
                                  labelText: 'Advance Paid',
                                  prefixText: '${currency.symbol} ',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _deadlineController,
                        decoration: const InputDecoration(
                          labelText: 'Deadline',
                          suffixIcon: Icon(Icons.calendar_month_rounded, size: 20),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final now = DateTime.now();
                          final initialDate = _deadlineController.text.trim().isNotEmpty
                              ? DateTime.tryParse(_deadlineController.text.trim()) ?? now
                              : now;
                          final date = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now.add(const Duration(days: 3650)),
                          );
                          if (date != null) {
                            setState(() {
                              _deadlineController.text = DateFormat('yyyy-MM-dd').format(date);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving || isPreselectedMissing ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Project'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
