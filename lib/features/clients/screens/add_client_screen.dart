import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../services/supabase_service.dart';

class AddClientScreen extends ConsumerStatefulWidget {
  const AddClientScreen({super.key});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final client = Client(
        id: '',
        userId: SupabaseService.userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        clientUserId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(clientProvider.notifier).addClient(client);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client added successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add client: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    Widget buildFields() {
      if (isDesktop) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      hintText: 'Enter client name',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'client@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+1 (555) 000-0000',
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company name',
                      hintText: 'Acme Corp',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Add private details or preferences',
              ),
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              hintText: 'Enter client name',
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'client@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+1 (555) 000-0000',
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: 'Company name',
              hintText: 'Acme Corp',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add private details or preferences',
            ),
            maxLines: 4,
            textInputAction: TextInputAction.newline,
          ),
        ],
      );
    }

    final bodyContent = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24.0 : 20.0,
            vertical: isDesktop ? 32.0 : 16.0,
          ),
          child: Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: isDark ? AppColors.card : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                  )
                : null,
            padding: EdgeInsets.all(isDesktop ? 32.0 : 0.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDesktop) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.person_add_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'New Client Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a client profile to track their payments, invoices, and work metrics.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  buildFields(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add Client'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          'Add Client',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
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
      body: AmbientGlowContainer(
        child: SafeArea(
          child: bodyContent,
        ),
      ),
    );
  }
}
