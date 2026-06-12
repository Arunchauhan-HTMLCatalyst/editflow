import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../providers/project_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_service.dart';

class AddProjectScreen extends ConsumerStatefulWidget {
  final String? preselectedClientId;
  const AddProjectScreen({super.key, this.preselectedClientId});

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
  }

  // Initialise _selectedClientId outside build() to avoid side-effects during
  // a build pass, which causes '_elements.contains(element)' framework errors.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedClientId == null && widget.preselectedClientId == null) {
      // Use ProviderScope.containerOf so we can read without watching.
      final container = ProviderScope.containerOf(context, listen: false);
      final clients = container.read(safeClientsProvider);
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
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.id ?? SupabaseService.userId;

      final project = Project(
        id: '',
        userId: userId,
        clientId: _selectedClientId!,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        receivedAmount: double.tryParse(_receivedController.text.trim()) ?? 0.0,
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

      // Pop immediately. By the time addProject() resolves, all synchronous
      // Riverpod state notifications have already fired. Using a post-frame
      // callback instead would keep the Form's _FormScope InheritedWidget alive
      // one extra frame while external consumers register as dependents on it,
      // then remove it while those dependents are still registered —
      // triggering the '_dependents.isEmpty' framework assertion.
      context.pop();
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
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Add Project',
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
                  onPressed: _save,
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
                        'No Clients Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You need to create a client before adding a project.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.push('/add-client'),
                        child: const Text('Add Client'),
                      ),
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
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClientId,
                        decoration: const InputDecoration(
                          labelText: 'Client *',
                        ),
                        dropdownColor: isDark ? AppColors.surface : Colors.white,
                        items: clients.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              c.company != null && c.company!.isNotEmpty
                                  ? '${c.name} (${c.company})'
                                  : c.name,
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
                        validator: (value) => value == null ? 'Client is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Project Name *',
                          hintText: 'Enter project name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Budget',
                                hintText: '0.00',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _receivedController,
                              decoration: const InputDecoration(
                                labelText: 'Advance Paid',
                                hintText: '0.00',
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
                          hintText: 'YYYY-MM-DD',
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
                          hintText: 'Enter project description or details',
                        ),
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
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
