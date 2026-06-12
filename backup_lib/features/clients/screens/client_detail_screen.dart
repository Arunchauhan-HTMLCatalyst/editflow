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
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_layout.dart';
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
  bool _isEditing = false;
  bool _isSaving = false;
  bool _contactExpanded = false;
  Client? _cachedClient;
  List<Project> _cachedProjects = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _companyController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
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

    print('[CLIENT DETAIL] BUILD id=${widget.clientId} clients=${clients.length} projects=${allProjects.length} found=${client != null} cached=${_cachedClient?.id}');

    if (client == null) {
      final isLoading = clientsAsync.isLoading;
      print('[CLIENT DETAIL] NOT FOUND - clients=${clients.length} loading=$isLoading');
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: isLoading
              ? CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Client not found',
                        style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text('Go back'),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppColors.textPrimary : null),
          onPressed: () => context.pop(),
        ),
        title: Text(cl.name),
        actions: _isEditing
            ? [
                TextButton(
                  onPressed: _isSaving ? null : _saveClient,
                  child: Text('Save'),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                  onPressed: () {
                    setState(() => _isEditing = true);
                    _nameController.text = cl.name;
                    _phoneController.text = cl.phone ?? '';
                    _emailController.text = cl.email ?? '';
                    _companyController.text = cl.company ?? '';
                    _notesController.text = cl.notes ?? '';
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _deleteClient(cl),
                ),
              ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppLayout.pagePadding(context)),
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
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: AppTextStyles.title2(isDark)),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.15), width: 0.5),
                        ),
                        child: Text(
                          client.company ?? 'Freelancer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
        SizedBox(height: AppSpacing.lg),

        _HealthChips(
          total: metrics.totalValue,
          revenue: metrics.revenue,
          pending: metrics.pending,
          projects: metrics.projectCount,
          isDark: isDark,
          currency: currency,
        ),
        SizedBox(height: AppSpacing.lg),

        if (client.email != null || client.phone != null) ...[
          GestureDetector(
            onTap: () => setState(() => _contactExpanded = !_contactExpanded),
            child: Row(
              children: [
                Icon(Icons.contact_mail_outlined, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('Contact', style: AppTextStyles.caption(isDark)),
                Spacer(),
                AnimatedRotation(
                  turns: _contactExpanded ? 0.5 : 0,
                  duration: Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: Column(
              children: [
                if (client.email != null)
                  _contactRow(isDark, Icons.email_outlined, client.email!),
                if (client.email != null && client.phone != null)
                  SizedBox(height: AppSpacing.sm),
                if (client.phone != null)
                  _contactRow(isDark, Icons.phone_outlined, client.phone!),
              ],
            ),
            crossFadeState: _contactExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 200),
          ),
          SizedBox(height: AppSpacing.lg),
        ],

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCreateProjectSheet,
                icon: Icon(Icons.add_rounded, size: 16),
                label: Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordPaymentSheet(clientProjects, currency),
                icon: Icon(Icons.payments_outlined, size: 16),
                label: Text('Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Projects', style: AppTextStyles.title3(isDark)),
            Text('${clientProjects.length} total', style: AppTextStyles.small(isDark)),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        if (clientProjects.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open_outlined, size: 36, color: AppColors.textMuted),
                    SizedBox(height: AppSpacing.sm),
                    Text('No projects yet', style: AppTextStyles.caption(isDark)),
                    SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _showCreateProjectSheet,
                      icon: Icon(Icons.add_rounded, size: 16),
                      label: Text('Create first project'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...clientProjects.map((p) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: ProjectCard(
                  project: p,
                  currency: currency,
                  onTap: () => context.push('/projects/${p.id}'),
                ),
              )),
        SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _contactRow(bool isDark, IconData icon, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimary : const Color(0xFF18181B))),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Name *'),
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phoneController,
          decoration: InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _companyController,
          decoration: InputDecoration(labelText: 'Company'),
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: 'Notes'),
          maxLines: 4,
        ),
        SizedBox(height: AppSpacing.xl),
        OutlinedButton(
          onPressed: () => setState(() => _isEditing = false),
          style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
          child: Text('Cancel'),
        ),
        SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  void _showCreateProjectSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final nameController = TextEditingController();
        final descController = TextEditingController();
        final priceController = TextEditingController();
        final receivedController = TextEditingController();
        final deadlineController = TextEditingController();
        bool isSaving = false;
        final userId = SupabaseService.userId;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.pageHorizontal,
                right: AppSpacing.pageHorizontal,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text('Create Project', style: AppTextStyles.title3(isDark)),
                  SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Project Name *'),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: receivedController,
                    decoration: InputDecoration(labelText: 'Advance Payment'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: deadlineController,
                    decoration: InputDecoration(
                      labelText: 'Deadline (YYYY-MM-DD)',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                        initialDatePickerMode: DatePickerMode.day,
                      );
                      if (date != null) {
                        deadlineController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  SizedBox(height: AppSpacing.lg),
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
                            try {
                              await ref.read(projectProvider.notifier).addProject(project);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Project created')),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Create Project'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                left: AppSpacing.pageHorizontal,
                right: AppSpacing.pageHorizontal,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text('Record Payment', style: AppTextStyles.title3(isDark)),
                  SizedBox(height: AppSpacing.lg),
                  Text('Select Project', style: AppTextStyles.caption(isDark)),
                  SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : const Color(0xFFF1F1F3),
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      border: Border.all(color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7), width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedProject?.id,
                        hint: Text('Choose a project', style: TextStyle(color: AppColors.textMuted)),
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
                    SizedBox(height: AppSpacing.md),
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.card : const Color(0xFFF1F1F3),
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Price: ${currency.format(selectedProject!.price)}',
                                style: AppTextStyles.caption(isDark)),
                          ),
                          Text('Advance: ${currency.format(selectedProject!.receivedAmount)}',
                              style: AppTextStyles.label(isDark)),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(labelText: 'New Advance Payment'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newAmount = double.tryParse(amountController.text.trim());
                              if (newAmount == null || newAmount < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Enter a valid amount')),
                                );
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              final updated = selectedProject!.copyWith(receivedAmount: newAmount);
                              try {
                                await ref.read(projectProvider.notifier).updateProject(updated);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Payment recorded')),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Save Payment'),
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
    setState(() => _isSaving = true);
    final clients = ref.read(clientProvider.notifier);
    final existing = ref.read(clientProvider).valueOrNull?.firstWhere(
          (c) => c.id == widget.clientId,
        );
    if (existing != null) {
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
        title: Text('Delete Client'),
        content: Text('Delete ${client.name}? This cannot be undone.'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(clientProvider.notifier).deleteClient(widget.clientId);
      if (context.mounted) context.pop();
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
            Expanded(child: _chip('Total', currency.format(total), AppColors.primary, isDark, Icons.credit_card_rounded)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _chip('Revenue', currency.format(revenue), AppColors.success, isDark, Icons.trending_up_rounded)),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _chip('Pending', currency.format(pending), AppColors.warning, isDark, Icons.hourglass_empty_rounded)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _chip('Projects', '$projects', AppColors.info, isDark, Icons.folder_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, String value, Color color, bool isDark, IconData icon) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimary : const Color(0xFF18181B))),
        ],
      ),
    );
  }
}
