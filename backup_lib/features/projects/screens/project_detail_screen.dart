import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../providers/project_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../core/theme/app_layout.dart';
import '../../../shared/widgets/status_badge.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _receivedController;
  late TextEditingController _deadlineController;

  Project? _cachedProject;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _receivedController = TextEditingController();
    _deadlineController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _receivedController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));

    return projectAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_rounded, size: 48, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                'Project not found or failed to load',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(projectDetailProvider(widget.projectId)),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (project) {
        final p = project;
        final oldCached = _cachedProject;
        _cachedProject = p;

        if (_isEditing && oldCached != null && p != oldCached) {
          _populateControllers(p);
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? AppColors.textPrimary : null),
              onPressed: () => context.go('/clients/${p.clientId}'),
            ),
            title: Text(p.name),
            actions: _isEditing
                ? [
                    TextButton(
                      onPressed: _isSaving ? null : () => _saveProject(p),
                      child: Text('Save'),
                    ),
                  ]
                : [
                    IconButton(
                      icon: Icon(Icons.share_outlined, color: AppColors.textSecondary),
                      onPressed: () => _shareProject(p),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                      onPressed: () {
                        setState(() => _isEditing = true);
                        _populateControllers(p);
                      },
                    ),
                  ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppLayout.pagePadding(context)),
            child: _isEditing
                ? _buildEditForm(isDark, p)
                : _buildDetail(isDark, p, currency),
          ),
        );
      },
    );
  }

  void _populateControllers(Project project) {
    _nameController.text = project.name;
    _descriptionController.text = project.description ?? '';
    _priceController.text = project.price.toStringAsFixed(0);
    _receivedController.text = project.receivedAmount.toStringAsFixed(0);
    _deadlineController.text = project.deadline != null
        ? DateFormat('yyyy-MM-dd').format(project.deadline!)
        : '';
  }

  Widget _miniStat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: AppTextStyles.statValue(isDark)),
      ],
    );
  }

  Widget _buildDetail(bool isDark, Project project, CurrencyConfig currency) {
    final progress = project.price > 0
        ? (project.receivedAmount / project.price * 100).clamp(0.0, 100.0)
        : 0.0;
    final overdue = project.deadline != null &&
        project.deadline!.isBefore(DateTime.now()) &&
        project.status != ProjectStatus.paid;
    final initials = project.clientName != null && project.clientName!.isNotEmpty
        ? project.clientName!.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero header card
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.card : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent top bar
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.info]),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project name
                    Text(project.name, style: AppTextStyles.title1(isDark)),
                    SizedBox(height: AppSpacing.sm),
                    // Client row
                    if (project.clientName != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(project.clientName!, style: AppTextStyles.body(isDark)),
                          ],
                        ),
                      ),
                    Divider(height: 1, color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7)),
                    SizedBox(height: AppSpacing.sm),
                    // Amount + Status row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _miniStat('Total', currency.format(project.price), isDark),
                              SizedBox(height: 4),
                              _miniStat('Advance', currency.format(project.receivedAmount), isDark),
                              SizedBox(height: 4),
                              _miniStat('Remaining', currency.format(project.remainingAmount), isDark),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(status: project.status),
                            if (project.deadline != null) ...[
                              SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 11, color: overdue ? AppColors.error : AppColors.textMuted),
                                  SizedBox(width: 3),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(project.deadline!),
                                    style: TextStyle(fontSize: 11, color: overdue ? AppColors.error : AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),

        // Payment progress
        _PaymentProgress(
          progress: progress,
          received: project.receivedAmount,
          remaining: project.remainingAmount,
          total: project.price,
          currency: currency,
          isDark: isDark,
        ),
        SizedBox(height: AppSpacing.lg),

        // Status pipeline — tappable
        _StatusPipeline(
          currentStatus: project.status,
          isDark: isDark,
          onStatusTap: (s) => _changeStatus(project, s),
        ),
        SizedBox(height: AppSpacing.lg),

        // Details
        Text('Details', style: AppTextStyles.caption(isDark)),
        SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.card : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7), width: 0.5),
          ),
          child: Column(
            children: [
              if (project.description != null && project.description!.isNotEmpty)
                _detailBlock(isDark, Icons.description_outlined, 'Description', project.description!),
              if (project.description != null && project.description!.isNotEmpty && project.deadline != null)
                Container(height: 1, margin: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
                    color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7)),
              if (project.deadline != null)
                _detailBlock(isDark, Icons.calendar_today_outlined, 'Deadline',
                    DateFormat('MMM d, yyyy').format(project.deadline!)),
              if (project.deadline != null)
                Container(height: 1, margin: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
                    color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7)),
              _detailBlock(isDark, Icons.access_time_rounded, 'Created',
                  DateFormat('MMM d, yyyy').format(project.createdAt)),
              if (project.description == null || project.description!.isEmpty)
                Container(height: 1, margin: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
                    color: isDark ? AppColors.border.withValues(alpha: 0.3) : const Color(0xFFE4E4E7)),
              _detailBlock(isDark, Icons.update_rounded, 'Updated',
                  DateFormat('MMM d, yyyy').format(project.updatedAt)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _detailBlock(bool isDark, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: AppColors.textSecondary),
          ),
          SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppColors.textPrimary : const Color(0xFF18181B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(bool isDark, Project project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Project Name'),
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _priceController,
          decoration: InputDecoration(labelText: 'Price'),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _receivedController,
          decoration: InputDecoration(labelText: 'Advance Payment'),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: AppSpacing.md),
        TextField(
          controller: _deadlineController,
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
              _deadlineController.text = DateFormat('yyyy-MM-dd').format(date);
            }
          },
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

  Future<void> _saveProject(Project project) async {
    setState(() => _isSaving = true);

    final updated = project.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null : _descriptionController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? project.price,
      receivedAmount: double.tryParse(_receivedController.text.trim()) ?? project.receivedAmount,
      deadline: _deadlineController.text.trim().isNotEmpty
          ? DateTime.tryParse(_deadlineController.text.trim()) : null,
    );

    try {
      await ref.read(projectProvider.notifier).updateProject(updated);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _shareProject(Project project) async {
    final currency = ref.read(currencyProvider);
    final buf = StringBuffer()
      ..writeln('📋 ${project.name}')
      ..writeln()
      ..writeln('Status: ${project.status.displayName}')
      ..writeln('Amount: ${currency.format(project.price)}')
      ..writeln('Advance: ${currency.format(project.receivedAmount)}')
      ..writeln('Remaining: ${currency.format(project.remainingAmount)}');
    if (project.deadline != null) {
      buf.writeln('Deadline: ${DateFormat('MMM d, yyyy').format(project.deadline!)}');
    }
    if (project.clientName != null) {
      buf.writeln('Client: ${project.clientName}');
    }
    if (project.description != null && project.description!.isNotEmpty) {
      buf.writeln();
      buf.writeln(project.description);
    }
    buf.writeln();
    buf.writeln('Shared from EditFlow');
    await SharePlus.instance.share(
      ShareParams(text: buf.toString(), title: project.name),
    );
  }

  Future<void> _changeStatus(Project project, ProjectStatus newStatus) async {
    if (newStatus == project.status) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Status'),
        content: Text('Move "${project.name}" to "${newStatus.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(projectProvider.notifier).updateStatus(project.id, newStatus);
    }
  }
}

class _PaymentProgress extends StatelessWidget {
  final double progress;
  final double received;
  final double remaining;
  final double total;
  final CurrencyConfig currency;
  final bool isDark;

  const _PaymentProgress({
    required this.progress,
    required this.received,
    required this.remaining,
    required this.total,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
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
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.payments_rounded, size: 13, color: AppColors.success),
              ),
              SizedBox(width: 8),
              Text('Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Stats row
          Row(
            children: [
              _statBlock('Received', currency.format(received), AppColors.success, isDark),
              SizedBox(width: AppSpacing.sm),
              _statBlock('Remaining', currency.format(remaining), isDark ? AppColors.textPrimary : const Color(0xFF18181B), isDark),
              Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${progress.toStringAsFixed(0)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimary : const Color(0xFF18181B))),
                  Text('complete', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: isDark ? AppColors.border.withValues(alpha: 0.5) : const Color(0xFFE4E4E7)),
                FractionallySizedBox(
                  widthFactor: (progress / 100).clamp(0, 1),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.success]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBlock(String label, String value, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _StatusPipeline extends StatelessWidget {
  final ProjectStatus currentStatus;
  final bool isDark;
  final void Function(ProjectStatus)? onStatusTap;

  const _StatusPipeline({
    required this.currentStatus,
    required this.isDark,
    this.onStatusTap,
  });

  static const _steps = [
    _StepData('Yet to Start', ProjectStatus.yetToStart, 'Project created, work not begun'),
    _StepData('In Progress', ProjectStatus.inProgress, 'Actively working on the project'),
    _StepData('Revision Pending', ProjectStatus.revisionPending, 'Awaiting client feedback'),
    _StepData('Completed', ProjectStatus.completed, 'Work done, payment pending'),
    _StepData('Paid', ProjectStatus.paid, 'Fully paid and closed'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((s) => s.status == currentStatus);
    if (currentIndex < 0) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
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
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.alt_route_rounded, size: 13, color: AppColors.primary),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
              ),
              Text('${currentIndex + 1} / ${_steps.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ...List.generate(_steps.length, (i) {
            final step = _steps[i];
            final isCompleted = i < currentIndex;
            final isCurrent = i == currentIndex;
            final isLast = i == _steps.length - 1;

            return _pipelineStep(
              step: step,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: isLast,
              isDark: isDark,
              onTap: onStatusTap != null ? () => onStatusTap!(step.status) : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _pipelineStep({
    required _StepData step,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final green = const Color(0xFF22C55E);
    final blue = const Color(0xFF3B82F6);
    final muted = AppColors.textMuted.withValues(alpha: 0.4);

    final dotColor = isCompleted ? green : isCurrent ? blue : muted;
    final cardBg = isCurrent
        ? blue.withValues(alpha: 0.06)
        : isCompleted
            ? green.withValues(alpha: 0.04)
            : (isDark ? AppColors.card : Colors.white);
    final cardBorder = isCurrent
        ? blue.withValues(alpha: 0.2)
        : isCompleted
            ? green.withValues(alpha: 0.12)
            : (isDark ? AppColors.border.withValues(alpha: 0.15) : const Color(0xFFE4E4E7));
    final titleColor = isCompleted || isCurrent
        ? (isDark ? AppColors.textPrimary : const Color(0xFF18181B))
        : AppColors.textMuted;
    final hintColor = isCurrent
        ? blue.withValues(alpha: 0.7)
        : isCompleted
            ? green.withValues(alpha: 0.6)
            : AppColors.textMuted.withValues(alpha: 0.5);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // timeline column
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: isCurrent ? 18.0 : 14.0,
                    height: isCurrent ? 18.0 : 14.0,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: blue.withValues(alpha: 0.35), width: 3)
                          : null,
                      boxShadow: isCurrent
                          ? [BoxShadow(color: blue.withValues(alpha: 0.25), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: isCompleted
                              ? green.withValues(alpha: 0.4)
                              : (isDark ? AppColors.border.withValues(alpha: 0.4) : const Color(0xFFE4E4E7)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            // step card
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  splashColor: blue.withValues(alpha: 0.06),
                  highlightColor: blue.withValues(alpha: 0.03),
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder, width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                step.hint,
                                style: TextStyle(fontSize: 11, color: hintColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        if (isCompleted)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: green),
                                SizedBox(width: 3),
                                Text('Done', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: green)),
                              ],
                            ),
                          ),
                        if (isCurrent)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 10, color: blue),
                                SizedBox(width: 3),
                                Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: blue)),
                              ],
                            ),
                          ),
                        if (!isCompleted && !isCurrent)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Next', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted.withValues(alpha: 0.6))),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, size: 12, color: AppColors.textMuted.withValues(alpha: 0.4)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepData {
  final String label;
  final ProjectStatus status;
  final String hint;
  const _StepData(this.label, this.status, this.hint);
}
