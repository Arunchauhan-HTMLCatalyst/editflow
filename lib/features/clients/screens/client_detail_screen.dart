import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../../projects/models/project.dart';
import '../../projects/models/project_status.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/widgets/project_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../services/supabase_service.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _companyController;
  late TextEditingController _notesController;
  late TextEditingController _clientUserIdController;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _contactExpanded = false;
  Client? _cachedClient;
  List<Project> _cachedProjects = [];
  final _editFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _companyController = TextEditingController();
    _notesController = TextEditingController();
    _clientUserIdController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    _clientUserIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clientsAsync = ref.watch(clientProvider);
    final currency = ref.watch(currencyProvider);

    final allProjects = ref.watch(safeProjectsProvider);
    final clients = clientsAsync.valueOrNull ?? [];
    Client? client;
    for (final c in clients) {
      if (c.id == widget.clientId) {
        client = c;
        break;
      }
    }

    if (client != null) {
      _cachedClient = client;
    } else if (_cachedClient != null && _cachedClient!.id == widget.clientId) {
      client = _cachedClient;
    }

    debugPrint('[CLIENT DETAIL] BUILD id=${widget.clientId} clients=${clients.length} projects=${allProjects.length} found=${client != null} cached=${_cachedClient?.id}');

    if (client == null) {
      final isLoading = clientsAsync.isLoading;
      debugPrint('[CLIENT DETAIL] NOT FOUND - clients=${clients.length} loading=$isLoading');
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
        ),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text('Client not found',
                        style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
        ),
      );
    }

    final cl = client;
    final metrics = ref.watch(clientMetricsProvider(widget.clientId));
    final clientProjects = allProjects
        .where((p) => p.clientId == widget.clientId)
        .toList();
    _cachedProjects = clientProjects.isNotEmpty ? clientProjects : _cachedProjects;
    final displayProjects = clientProjects.isNotEmpty ? clientProjects : _cachedProjects;

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
          _isEditing ? 'Edit Details' : cl.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: _isEditing
            ? [
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
                      onPressed: _saveClient,
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
              ]
            : [
                CupertinoButton(
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
                    child: const Icon(
                      CupertinoIcons.pencil,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _isEditing = true);
                    _nameController.text = cl.name;
                    _phoneController.text = cl.phone ?? '';
                    _emailController.text = cl.email ?? '';
                    _companyController.text = cl.company ?? '';
                    _notesController.text = cl.notes ?? '';
                    _clientUserIdController.text = cl.clientUserId ?? '';
                  },
                ),
                const SizedBox(width: 8),
                CupertinoButton(
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
                    child: const Icon(
                      CupertinoIcons.trash,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                  onPressed: () => _deleteClient(cl),
                ),
                const SizedBox(width: 12),
              ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: _isEditing
              ? _buildEditForm(isDark)
              : _buildDetail(isDark, cl, metrics, displayProjects, currency),
        ),
      ),
    );
  }

  Widget _buildDetail(
    bool isDark,
    Client client,
    ClientMetrics metrics,
    List<Project> clientProjects,
    CurrencyConfig currency,
  ) {
    final initials = client.name.isNotEmpty
        ? client.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primaryNeon.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: AppTextStyles.title2(isDark).copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.15), width: 0.5),
                        ),
                        child: Text(
                          client.company ?? 'Freelancer',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _HealthChips(
          total: metrics.totalValue,
          revenue: metrics.revenue,
          pending: metrics.pending,
          projects: metrics.projectCount,
          isDark: isDark,
          currency: currency,
        ),
        const SizedBox(height: 24),

        if (client.email != null || client.phone != null) ...[
          GestureDetector(
            onTap: () => setState(() => _contactExpanded = !_contactExpanded),
            child: Row(
              children: [
                const Icon(CupertinoIcons.info_circle, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Contact Information', style: AppTextStyles.caption(isDark).copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                AnimatedRotation(
                  turns: _contactExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                if (client.email != null && client.email!.isNotEmpty)
                  _contactRow(isDark, CupertinoIcons.mail, client.email!),
                if (client.email != null && client.email!.isNotEmpty && client.phone != null && client.phone!.isNotEmpty)
                  const SizedBox(height: 10),
                if (client.phone != null && client.phone!.isNotEmpty)
                  _contactRow(isDark, CupertinoIcons.phone, client.phone!),
              ],
            ),
            crossFadeState: _contactExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 24),
        ],

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCreateProjectSheet,
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordPaymentSheet(clientProjects, currency),
                icon: const Icon(CupertinoIcons.creditcard, size: 16),
                label: const Text('Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Projects', style: AppTextStyles.title3(isDark).copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${clientProjects.length} total', style: AppTextStyles.small(isDark).copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        if (clientProjects.isEmpty)
          Card(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.folder_badge_plus, size: 36, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No projects yet', style: AppTextStyles.caption(isDark)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _showCreateProjectSheet,
                        icon: const Icon(CupertinoIcons.add, size: 16),
                        label: const Text('Create first project'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          ...clientProjects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ProjectCard(
                  project: p,
                  currency: currency,
                  onTap: () => context.push('/projects/${p.id}'),
                ),
              )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _contactRow(bool isDark, IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(bool isDark) {
    return Form(
      key: _editFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyController,
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _clientUserIdController,
            decoration: const InputDecoration(
              labelText: 'Client User ID (for portal access)',
              hintText: 'Paste client\'s Supabase auth ID',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final trimmed = v.trim();
              final uuidRegExp = RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              );
              if (!uuidRegExp.hasMatch(trimmed)) {
                return 'Enter a valid Supabase User ID (UUID format)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 4,
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => setState(() => _isEditing = false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showCreateProjectSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.read(currencyProvider);
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final receivedController = TextEditingController();
    final deadlineController = TextEditingController();
    final userId = SupabaseService.userId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create Project',
                    style: AppTextStyles.title3(isDark).copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name *',
                      hintText: 'Enter project name',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Project brief or requirements',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText: 'Price',
                            hintText: '0.00',
                            prefixText: '${currency.symbol} ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: receivedController,
                          decoration: InputDecoration(
                            labelText: 'Advance Payment',
                            hintText: '0.00',
                            prefixText: '${currency.symbol} ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: deadlineController,
                    decoration: InputDecoration(
                      labelText: 'Deadline (YYYY-MM-DD)',
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: IconButton(
                        icon: const Icon(CupertinoIcons.calendar, size: 18),
                        onPressed: () async {
                          final now = DateTime.now();
                          final parsedDate = DateTime.tryParse(deadlineController.text.trim());
                          final firstDate = now.subtract(const Duration(days: 365 * 10));
                          final lastDate = now.add(const Duration(days: 365 * 10));
                          final initialDate = (parsedDate != null && parsedDate.isAfter(firstDate) && parsedDate.isBefore(lastDate))
                              ? parsedDate
                              : now;
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: initialDate,
                            firstDate: firstDate,
                            lastDate: lastDate,
                            initialDatePickerMode: DatePickerMode.day,
                          );
                          if (date != null) {
                            deadlineController.text = DateFormat('yyyy-MM-dd').format(date);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) return;
                            setSheetState(() => isSaving = true);
                            final project = Project(
                              id: '',
                              userId: userId,
                              clientId: widget.clientId,
                              name: nameController.text.trim(),
                              description: descController.text.trim().isEmpty
                                  ? null : descController.text.trim(),
                              price: double.tryParse(priceController.text.trim()) ?? 0,
                              receivedAmount: double.tryParse(receivedController.text.trim()) ?? 0,
                              deadline: deadlineController.text.trim().isNotEmpty
                                  ? DateTime.tryParse(deadlineController.text.trim()) : null,
                              status: ProjectStatus.yetToStart,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref.read(projectProvider.notifier).addProject(project);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Project created')),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (ctx.mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Project'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      descController.dispose();
      priceController.dispose();
      receivedController.dispose();
      deadlineController.dispose();
    });
  }

  void _showRecordPaymentSheet(List<Project> clientProjects, CurrencyConfig currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Project? selectedProject;
    final amountController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Record Payment',
                    style: AppTextStyles.title3(isDark).copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Project',
                    style: AppTextStyles.caption(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedProject?.id,
                        dropdownColor: isDark ? AppColors.surface : Colors.white,
                        hint: const Text('Choose a project', style: TextStyle(color: AppColors.textMuted)),
                        items: clientProjects.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (id) {
                          setSheetState(() {
                            selectedProject = clientProjects.firstWhere((p) => p.id == id);
                            amountController.text =
                                selectedProject!.receivedAmount.toStringAsFixed(0);
                          });
                        },
                      ),
                    ),
                  ),
                  if (selectedProject != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Price: ${currency.format(selectedProject!.price)}',
                                style: AppTextStyles.caption(isDark).copyWith(fontWeight: FontWeight.w600)),
                          ),
                          Text('Advance: ${currency.format(selectedProject!.receivedAmount)}',
                              style: AppTextStyles.label(isDark).copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'New Advance Payment',
                        hintText: 'Enter payment amount',
                        prefixText: '${currency.symbol} ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newAmount = double.tryParse(amountController.text.trim());
                              if (newAmount == null || newAmount < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Enter a valid amount')),
                                );
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              final updated = selectedProject!.copyWith(receivedAmount: newAmount);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref.read(projectProvider.notifier).updateProject(updated);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Payment recorded')),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (ctx.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Payment'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveClient() async {
    if (!_editFormKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final clients = ref.read(clientProvider.notifier);
    final existing = ref.read(clientProvider).valueOrNull?.firstWhere(
          (c) => c.id == widget.clientId,
        );
    if (existing != null) {
      final updated = Client(
        id: existing.id,
        userId: existing.userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        clientUserId: _clientUserIdController.text.trim().isEmpty ? null : _clientUserIdController.text.trim(),
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await clients.updateClient(updated);
    }
    setState(() {
      _isEditing = false;
      _isSaving = false;
    });
  }

  Future<void> _deleteClient(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Delete ${client.name}? This cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(clientProvider.notifier).deleteClient(widget.clientId);
      if (!mounted) return;
      context.pop();
    }
  }
}

class _HealthChips extends StatelessWidget {
  final double total;
  final double revenue;
  final double pending;
  final int projects;
  final bool isDark;
  final CurrencyConfig currency;

  const _HealthChips({
    required this.total,
    required this.revenue,
    required this.pending,
    required this.projects,
    required this.isDark,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _chip('Total value', currency.format(total), AppColors.primary, isDark, CupertinoIcons.money_dollar)),
            const SizedBox(width: 12),
            Expanded(child: _chip('Revenue received', currency.format(revenue), AppColors.success, isDark, CupertinoIcons.check_mark_circled)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _chip('Pending balance', currency.format(pending), AppColors.warning, isDark, CupertinoIcons.hourglass)),
            const SizedBox(width: 12),
            Expanded(child: _chip('Active projects', '$projects', AppColors.info, isDark, CupertinoIcons.folder)),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, String value, Color color, bool isDark, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
