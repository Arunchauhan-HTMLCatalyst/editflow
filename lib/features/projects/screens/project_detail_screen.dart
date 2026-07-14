import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../providers/project_provider.dart';
import '../providers/review_provider.dart';
import '../models/review_video.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';
import '../providers/comment_provider.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/rich_link_text.dart';
import '../../../shared/widgets/ambient_glow_container.dart';

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
  late TextEditingController _commentController;

  Project? _cachedProject;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _receivedController = TextEditingController();
    _deadlineController = TextEditingController();
    _commentController = TextEditingController();


  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _receivedController.dispose();
    _deadlineController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final isClient = ref.watch(settingsProvider).isClientMode;
    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));

    return projectAsync.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
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
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
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
        body: AmbientGlowContainer(
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
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
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
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
        body: AmbientGlowContainer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Project not found or failed to load',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(projectDetailProvider(widget.projectId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
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
          backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
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
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.back,
                    size: 18,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(isClient ? '/dashboard' : '/clients/${p.clientId}');
                  }
                },
              ),
            ),
            title: Text(
              _isEditing ? 'Edit Project' : p.name,
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
                          onPressed: () => _saveProject(p),
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
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.share,
                          size: 18,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                        ),
                      ),
                      onPressed: () => _shareProject(p),
                    ),
                    if (!isClient) ...[
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 18,
                            color: AppColors.error,
                          ),
                        ),
                        onPressed: () => _deleteProject(p),
                      ),
                    ],
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 18,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                        ),
                      ),
                      onPressed: () {
                        setState(() => _isEditing = true);
                        _populateControllers(p);
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
          ),
          body: AmbientGlowContainer(
            topGlowColor: _getStatusGlowColor(p.status),
            bottomGlowColor: _getStatusGlowColor(p.status),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 800;

                  if (_isEditing) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(projectProvider);
                        ref.invalidate(latestReviewProvider(p.id));
                        await ref.read(projectProvider.notifier).refresh();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        child: _buildEditForm(isDark, p),
                      ),
                    );
                  }

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left column: Scrollable details
                        Expanded(
                          flex: 6,
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(projectProvider);
                              ref.invalidate(latestReviewProvider(p.id));
                              await ref.read(projectProvider.notifier).refresh();
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildLeftDetailWidgets(isDark, p, currency, isClient, isDesktop: true),
                              ),
                            ),
                          ),
                        ),
                        // Vertical divider
                        Container(
                          width: 1,
                          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                        ),
                        // Right column: Review Feedback & Status Comments
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Builder(
                                   builder: (context) {
                                     final commentsCount = ref.watch(projectReviewCommentsCountProvider(p.id));
                                     final showRevisionBanner = !isClient && 
                                         (p.status == ProjectStatus.revisionPending || 
                                          (p.status == ProjectStatus.reviewPending && commentsCount > 0));
                                     if (showRevisionBanner) {
                                       return Padding(
                                         padding: const EdgeInsets.only(bottom: 16.0),
                                         child: _buildRevisionPendingBanner(context, isDark, p),
                                       );
                                     }
                                     return const SizedBox.shrink();
                                   },
                                 ),
                                if (p.status == ProjectStatus.reviewPending ||
                                    p.status == ProjectStatus.revisionPending ||
                                    p.status == ProjectStatus.completed) ...[
                                  _buildReviewSection(isDark, p, isClient),
                                  const SizedBox(height: 20),
                                ],
                                _buildCommentsSection(isDark, p),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile layout
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(projectProvider);
                      ref.invalidate(latestReviewProvider(p.id));
                      await ref.read(projectProvider.notifier).refresh();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: _buildDetail(isDark, p, currency, isClient),
                    ),
                  );
                },
              ),
            ),
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

  Color _getStatusGlowColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.paid:
      case ProjectStatus.completed:
        return const Color(0xFF10B981);
      case ProjectStatus.inProgress:
        return AppColors.primary;
      case ProjectStatus.reviewPending:
      case ProjectStatus.revisionPending:
        return const Color(0xFFF59E0B);
      case ProjectStatus.yetToStart:
        return const Color(0xFF64748B);
    }
  }


  List<Widget> _buildLeftDetailWidgets(bool isDark, Project project, CurrencyConfig currency, bool isClient, {required bool isDesktop}) {
    final progress = project.price > 0
        ? (project.receivedAmount / project.price * 100).clamp(0.0, 100.0)
        : 0.0;
    final overdue = project.deadline != null &&
        project.deadline!.isBefore(DateTime.now()) &&
        project.status != ProjectStatus.paid;
    final showFreelancer = isClient && project.freelancerName != null;
    final displayName = showFreelancer ? project.freelancerName : project.clientName;
    final initials = displayName != null && displayName.isNotEmpty
        ? displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return [
      // Hero header card
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF171D1F), const Color(0xFF101517)]
                : [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.primary.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Project Name & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: AppTextStyles.title1(isDark).copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(status: project.status),
                ],
              ),
              
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 12),
              
              // Bottom Row: Profile & Deadline
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Profile Block
                  if (displayName != null)
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showFreelancer ? 'FREELANCER' : 'CLIENT',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.55),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  
                  // Deadline Block (Glass Pill)
                  if (project.deadline != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: overdue ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: overdue ? 0.35 : 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 13,
                            color: Colors.white.withValues(alpha: overdue ? 0.95 : 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d').format(project.deadline!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: overdue ? 0.95 : 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Payment progress
      _PaymentProgress(
        progress: progress,
        received: project.receivedAmount,
        remaining: project.remainingAmount,
        total: project.price,
        currency: currency,
        isDark: isDark,
      ),
      const SizedBox(height: 16),

      // Status pipeline — read-only in client mode
      _StatusPipeline(
        currentStatus: project.status,
        isDark: isDark,
        onStatusTap: isClient ? null : (s) => _changeStatus(project, s),
      ),
      const SizedBox(height: 20),

      if (!isDesktop)
        Builder(
          builder: (context) {
            final commentsCount = ref.watch(projectReviewCommentsCountProvider(project.id));
            final showRevisionBanner = !isClient && 
                (project.status == ProjectStatus.revisionPending || 
                 (project.status == ProjectStatus.reviewPending && commentsCount > 0));
            if (showRevisionBanner) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildRevisionPendingBanner(context, isDark, project),
              );
            }
            return const SizedBox.shrink();
          },
        ),

      if (!isDesktop &&
          (project.status == ProjectStatus.reviewPending ||
              project.status == ProjectStatus.revisionPending ||
              project.status == ProjectStatus.completed)) ...[
        _buildReviewSection(isDark, project, isClient),
        const SizedBox(height: 20),
      ],

      // Details title
      Text(
        'PROJECT METADATA & DETAILS',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 10),
      
      // Full-width Description Card
      if (project.description != null && project.description!.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
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
                  const Icon(CupertinoIcons.doc_text, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RichLinkText(
                text: project.description!,
                isDark: isDark,
                textStyle: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],

      // Dedicated Horizontal Dates Card
      _buildDatesCard(isDark, project, overdue),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildDetail(bool isDark, Project project, CurrencyConfig currency, bool isClient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildLeftDetailWidgets(isDark, project, currency, isClient, isDesktop: false),
        _buildCommentsSection(isDark, project),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDatesCard(bool isDark, Project project, bool overdue) {
    final hasDeadline = project.deadline != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          if (hasDeadline) ...[
            Expanded(
              child: _dateItem(
                icon: CupertinoIcons.calendar,
                label: 'DEADLINE',
                value: DateFormat('MMM d, yyyy').format(project.deadline!),
                valueColor: overdue ? AppColors.error : AppColors.primary,
              ),
            ),
            _verticalDivider(isDark),
          ],
          Expanded(
            child: _dateItem(
              icon: CupertinoIcons.time,
              label: 'CREATED',
              value: DateFormat('MMM d, yyyy').format(project.createdAt),
              valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          _verticalDivider(isDark),
          Expanded(
            child: _dateItem(
              icon: CupertinoIcons.refresh,
              label: 'UPDATED',
              value: DateFormat('MMM d, yyyy').format(project.updatedAt),
              valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12.0),
      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
    );
  }  Widget _buildRevisionPendingBanner(BuildContext context, bool isDark, Project project) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Client requested changes. Mark done once fixed.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _markRevisionsCompleted(context, project),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text('Mark Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Widget _buildCommentsSection(bool isDark, Project project) {
    final projectId = project.id;
    final commentsAsync = ref.watch(projectCommentsProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FEEDBACK & STATUS COMMENTS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        commentsAsync.when(
          data: (comments) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.card : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Column(
                children: [
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              CupertinoIcons.chat_bubble_2,
                              size: 32,
                              color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No feedback comments yet.',
                              style: TextStyle(
                                color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final timeStr = DateFormat('MMM d, h:mm a').format(comment.createdAt.toLocal());
                        final isOwnComment = comment.userId == SupabaseService.userId;

                        return Align(
                          alignment: isOwnComment ? Alignment.centerRight : Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.85,
                            alignment: isOwnComment ? Alignment.centerRight : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isOwnComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: isOwnComment ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isOwnComment) ...[
                                      Text(
                                        comment.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: comment.userId == project.userId
                                              ? (isDark ? AppColors.primary.withAlpha(26) : AppColors.primary.withAlpha(18))
                                              : (isDark ? Colors.teal.withAlpha(26) : Colors.teal.withAlpha(18)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          comment.userId == project.userId ? 'Freelancer' : 'Client',
                                          style: TextStyle(
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w800,
                                            color: comment.userId == project.userId
                                                ? AppColors.primary
                                                : (isDark ? Colors.tealAccent : Colors.teal.shade700),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'You',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                GestureDetector(
                                  onLongPress: isOwnComment ? () => _showCommentActions(context, isDark, comment, projectId) : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                                    decoration: BoxDecoration(
                                      color: isOwnComment
                                          ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.08))
                                          : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: isOwnComment ? const Radius.circular(12) : const Radius.circular(3),
                                        bottomRight: isOwnComment ? const Radius.circular(3) : const Radius.circular(12),
                                      ),
                                      border: Border.all(
                                        color: isOwnComment
                                            ? AppColors.primary.withValues(alpha: 0.2)
                                            : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        RichLinkText(
                                          text: comment.content,
                                          isDark: isDark,
                                          textStyle: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              if (isOwnComment) ...[
                                                const SizedBox(width: 4),
                                                GestureDetector(
                                                  onTap: () => _showCommentActions(context, isDark, comment, projectId),
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                                    child: Icon(
                                                      Icons.more_vert_rounded,
                                                      size: 13,
                                                      color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add feedback or comment...',
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE2E8F0), width: 0.8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE2E8F0), width: 0.8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF131320) : const Color(0xFFF8FAFC),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                          onSubmitted: (text) => _postComment(projectId, text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: () => _postComment(projectId, _commentController.text),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Failed to load comments: $err',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCommentActions(BuildContext context, bool isDark, Comment comment, String projectId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.card : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (comment.voiceUrl == null) // Only text comments can be edited
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                  title: const Text('Edit Comment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editComment(context, isDark, comment, projectId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                title: const Text('Delete Comment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteComment(context, isDark, comment, projectId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editComment(BuildContext context, bool isDark, Comment comment, String projectId) {
    final editController = TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.card : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Comment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Update your comment...',
            hintStyle: TextStyle(color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9),
          ),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.textMuted : const Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isEmpty || newContent == comment.content) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(commentRepositoryProvider).update(comment.id, newContent, comment.userId);
                ref.invalidate(projectCommentsProvider(projectId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment updated'), duration: Duration(seconds: 2)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteComment(BuildContext context, bool isDark, Comment comment, String projectId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.card : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Comment?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.textMuted : const Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(commentRepositoryProvider).delete(comment.id, comment.userId);
                ref.invalidate(projectCommentsProvider(projectId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment deleted'), duration: Duration(seconds: 2)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _postComment(String projectId, String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    _commentController.clear();

    // Get current authenticated user details
    final authState = ref.read(authProvider);
    final currentUser = authState.user;
    final name = currentUser?.userMetadata?['full_name'] as String? ?? 'User';
    final uid = currentUser?.id ?? SupabaseService.userId;

    final newComment = Comment(
      id: '',
      projectId: projectId,
      userId: uid,
      userName: name,
      content: cleanText,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(commentRepositoryProvider).create(newComment);
      // Refresh the comments list so the new comment shows immediately
      ref.invalidate(projectCommentsProvider(projectId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Widget _buildEditForm(bool isDark, Project project) {
    final currency = ref.read(currencyProvider);
    final isClient = ref.watch(settingsProvider).isClientMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Project Name'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: '${currency.symbol} ',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _receivedController,
                readOnly: isClient,
                decoration: InputDecoration(
                  labelText: 'Advance Payment',
                  prefixText: '${currency.symbol} ',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deadlineController,
          decoration: InputDecoration(
            labelText: 'Deadline (YYYY-MM-DD)',
            suffixIcon: IconButton(
              icon: const Icon(CupertinoIcons.calendar),
              onPressed: () async {
                final now = DateTime.now();
                final parsedDate = DateTime.tryParse(_deadlineController.text.trim());
                final firstDate = now.subtract(const Duration(days: 365 * 10));
                final lastDate = now.add(const Duration(days: 365 * 10));
                final initialDate = (parsedDate != null && parsedDate.isAfter(firstDate) && parsedDate.isBefore(lastDate))
                    ? parsedDate
                    : now;
                final date = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  initialDatePickerMode: DatePickerMode.day,
                );
                if (date != null) {
                  _deadlineController.text = DateFormat('yyyy-MM-dd').format(date);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => setState(() => _isEditing = false),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: const Text('Cancel'),
        ),
        const SizedBox(height: 24),
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
        title: const Text('Change Status'),
        content: Text('Move "${project.name}" to "${newStatus.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (newStatus == ProjectStatus.completed) {
        try {
          final review = await ref.read(reviewRepositoryProvider).getLatestReview(project.id);
          if (review != null) {
            final videos = await ref.read(reviewRepositoryProvider).getReviewVideos(review.id);
            final videoIds = videos.map((v) => v.id).toList();

            for (final vid in videoIds) {
              await SupabaseService.instance
                  .from('review_comments')
                  .delete()
                  .eq('video_id', vid)
                  .timeout(const Duration(seconds: 10));
            }

            await SupabaseService.instance
                .from('review_videos')
                .delete()
                .eq('review_id', review.id)
                .timeout(const Duration(seconds: 10));

            await SupabaseService.instance
                .from('review_shares')
                .delete()
                .eq('review_id', review.id)
                .timeout(const Duration(seconds: 10));

            await SupabaseService.instance
                .from('reviews')
                .update({'status': 'completed'})
                .eq('id', review.id)
                .timeout(const Duration(seconds: 10));
          }
        } catch (e) {
          debugPrint('Failed to clear review data on manual completed transition: $e');
        }
      }

      await ref.read(projectProvider.notifier).updateStatus(project.id, newStatus);
      if (newStatus == ProjectStatus.reviewPending) {
        try {
          final review = await ref.read(reviewRepositoryProvider).getLatestReview(project.id);
          if (review != null && (review.status == 'completed' || review.status == 'approved')) {
            await SupabaseService.instance
                .from('reviews')
                .update({'status': 'pending'})
                .eq('id', review.id);
          }
        } catch (e) {
          debugPrint('Failed to reopen review: $e');
        }
      }
      ref.invalidate(latestReviewProvider(project.id));
      await ref.read(projectProvider.notifier).refresh();
    }
  }

  Future<void> _deleteProject(Project project) async {
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(projectProvider.notifier).deleteProject(project.id);
        if (!mounted) return;
        if (router.canPop()) {
          router.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Widget _buildReviewSection(bool isDark, Project project, bool isClient) {
    final latestReviewAsync = ref.watch(latestReviewProvider(project.id));

    return latestReviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error loading review: $err'),
      data: (review) {
        if (review == null) {
          return Container(
            padding: const EdgeInsets.all(16.0),
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
                    const Icon(Icons.rate_review_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      isClient ? 'PENDING REVIEWS' : 'REVIEW FEEDBACK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isClient
                      ? 'No review submitted yet. Freelancer is preparing the review videos.'
                      : 'No review submitted yet.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondary : const Color(0xFF475569)),
                ),
                if (!isClient && project.status != ProjectStatus.completed) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showUploadReviewDialog(context, project),
                      child: const Text('Upload Review'),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final videosAsync = ref.watch(reviewVideosProvider(review.id));

        return Container(
          padding: const EdgeInsets.all(16.0),
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
                  const Icon(Icons.rate_review_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    isClient ? 'PENDING REVIEWS' : 'REVIEW FEEDBACK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getReviewStatusColor(review.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getReviewStatusColor(review.status).withValues(alpha: 0.2), width: 0.5),
                    ),
                    child: Text(
                      review.status.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _getReviewStatusColor(review.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              videosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error videos: $err'),
                data: (videos) {
                  if (videos.isEmpty) {
                    Widget emptyState;
                    if (review.status == 'completed' || review.status == 'approved') {
                      emptyState = Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.2), width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    review.status == 'completed'
                                        ? 'All previous revisions are completed'
                                        : 'Review Approved',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                            if (review.status == 'completed' && !isClient) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'If you want to send another version for review, please switch back to In Review status.',
                                style: TextStyle(fontSize: 11, color: Colors.green),
                              ),
                            ],
                          ],
                        ),
                      );
                    } else {
                      emptyState = const Text('No review videos uploaded.', style: TextStyle(fontSize: 12, color: AppColors.textMuted));
                    }
                    
                    if (isClient || project.status == ProjectStatus.completed) return emptyState;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        emptyState,
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showUploadReviewDialog(context, project),
                            child: const Text('Upload Review'),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      ...videos.map((video) {
                        final commentsAsync = ref.watch(reviewCommentsProvider(video.id));
                        return commentsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (comments) {
                            final count = comments.length;
                            final isApproved = review.status == 'approved' || video.isApproved;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                  width: 0.8,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isApproved ? Icons.check_circle_rounded : CupertinoIcons.video_camera_solid,
                                    size: 14,
                                    color: isApproved ? Colors.green : AppColors.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        video.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    if (video.isApproved) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Approved',
                                          style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  isApproved
                                      ? 'Approved'
                                      : (count > 0 ? '$count feedback points' : 'Awaiting feedback'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isApproved 
                                        ? Colors.green 
                                        : (count > 0 ? const Color(0xFFF59E0B) : AppColors.textMuted),
                                  ),
                                ),
                                trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
                                onTap: () => _openReviewScreen(video, project, isClient),
                              ),
                            );
                          },
                        );
                      }),

                      if (!isClient && project.status != ProjectStatus.completed) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _confirmReplaceReview(context, project),
                            child: const Text('Upload New Review'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getReviewStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'changes_requested':
        return const Color(0xFFF59E0B);
      case 'pending':
        return AppColors.primary;
      default:
        return const Color(0xFF71717A);
    }
  }

  void _openReviewScreen(ReviewVideo video, Project project, bool isClient) {
    context.push('/projects/${project.id}/reviews/${video.id}?isClient=$isClient');
  }

  Future<void> _confirmReplaceReview(BuildContext context, Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace Review?'),
        content: const Text('Uploading a new review will replace all current review videos and permanently delete all existing review comments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      _showUploadReviewDialog(context, project);
    }
  }

  Future<void> _showUploadReviewDialog(BuildContext context, Project project) async {
    final List<Map<String, TextEditingController>> controllers = [
      {'name': TextEditingController(), 'url': TextEditingController()}
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          
          return Dialog(
            backgroundColor: isDark ? AppColors.card : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(CupertinoIcons.video_camera_solid, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Review',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Share video drafts with your client',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(CupertinoIcons.xmark, size: 16),
                        onPressed: () {
                          for (final ctrl in controllers) {
                            ctrl['name']!.dispose();
                            ctrl['url']!.dispose();
                          }
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 0.8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.info_circle_fill, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please provide direct MP4/MOV URLs or Dropbox video links. Non-direct hosting links will open in a browser tab.',
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Video Form List
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(controllers.length, (index) {
                          final item = controllers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.01) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'VIDEO DRAFT #${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (controllers.length > 1)
                                      GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            controllers[index]['name']!.dispose();
                                            controllers[index]['url']!.dispose();
                                            controllers.removeAt(index);
                                          });
                                        },
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.trash, color: AppColors.error, size: 12),
                                            SizedBox(width: 4),
                                            Text(
                                              'Remove',
                                              style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: item['name'],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Video Title (e.g. Version 1 Rough Cut)',
                                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    prefixIcon: const Icon(CupertinoIcons.tag, size: 16),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFCBD5E1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: item['url'],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Video URL (Direct link or Dropbox)',
                                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    prefixIcon: const Icon(CupertinoIcons.link, size: 16),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFCBD5E1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // Actions block
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              controllers.add({'name': TextEditingController(), 'url': TextEditingController()});
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          icon: const Icon(CupertinoIcons.add, size: 14, color: AppColors.primary),
                          label: const Text('Add Video', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          for (final ctrl in controllers) {
                            ctrl['name']!.dispose();
                            ctrl['url']!.dispose();
                          }
                          Navigator.of(dialogContext).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          for (final ctrl in controllers) {
                            final name = ctrl['name']!.text.trim();
                            final url = ctrl['url']!.text.trim();
                            if (name.isEmpty || url.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please enter a Title and URL for all videos.')),
                              );
                              return;
                            }
                            
                            final urlLower = url.toLowerCase();
                            final isDropbox = urlLower.contains('dropbox.com');
                            final isDirectVideo = urlLower.endsWith('.mp4') ||
                                urlLower.endsWith('.mov') ||
                                urlLower.endsWith('.m4v') ||
                                urlLower.endsWith('.webm') ||
                                urlLower.contains('/mp4/') ||
                                urlLower.contains('.mp4?');
                                
                            if (!isDropbox && !isDirectVideo) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Strictly Dropbox links or Direct Video URLs (MP4) are supported for reviews.'),
                                ),
                              );
                              return;
                            }
                          }

                          final videoData = controllers.map((ctrl) => {
                            'name': ctrl['name']!.text.trim(),
                            'url': ctrl['url']!.text.trim(),
                          }).toList();

                          try {
                            showDialog(
                              context: dialogContext,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            await ref.read(reviewRepositoryProvider).submitNewReview(project.id, videoData);

                            for (final ctrl in controllers) {
                              ctrl['name']!.dispose();
                              ctrl['url']!.dispose();
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(); // pop loading
                              Navigator.of(dialogContext).pop(); // pop dialog
                            }

                            ref.invalidate(latestReviewProvider(project.id));
                            await ref.read(projectProvider.notifier).refresh();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Review videos submitted successfully!')),
                              );
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed to submit review: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Submit Review', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markRevisionsCompleted(BuildContext context, Project project) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final review = await ref.read(reviewRepositoryProvider).getLatestReview(project.id);
      if (review != null) {
        final videos = await ref.read(reviewRepositoryProvider).getReviewVideos(review.id);
        final videoIds = videos.map((v) => v.id).toList();

        for (final vid in videoIds) {
          await SupabaseService.instance
              .from('review_comments')
              .delete()
              .eq('video_id', vid)
              .timeout(const Duration(seconds: 10));
        }

        await SupabaseService.instance
            .from('review_videos')
            .delete()
            .eq('review_id', review.id)
            .timeout(const Duration(seconds: 10));

        await SupabaseService.instance
            .from('review_shares')
            .delete()
            .eq('review_id', review.id)
            .timeout(const Duration(seconds: 10));

        await SupabaseService.instance
            .from('reviews')
            .update({'status': 'completed'})
            .eq('id', review.id)
            .timeout(const Duration(seconds: 10));
      }

      await ref.read(projectProvider.notifier).updateStatus(project.id, ProjectStatus.completed);

      ref.invalidate(latestReviewProvider(project.id));
      await ref.read(projectProvider.notifier).refresh();

      if (context.mounted) {
        Navigator.of(context).pop(); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project completed! Review data cleared.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete revisions: $e')),
        );
      }
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(CupertinoIcons.shield_fill, size: 13, color: AppColors.success),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PAYMENT SUMMARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              // Secured tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'SECURED',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Main metric & circle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL BUDGET',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(total),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              // Radial Gauge
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        strokeWidth: 7,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const Text(
                          'PAID',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Split Cards for Details
          Row(
            children: [
              // Advance Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.green.withValues(alpha: 0.05)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.checkmark_circle_fill, size: 13, color: AppColors.success),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ADVANCE PAID',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(received),
                        style: TextStyle(
                           fontSize: 14.5,
                           fontWeight: FontWeight.w800,
                           color: isDark ? Colors.white : Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Remaining Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.orange.withValues(alpha: 0.05)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock_fill,
                            size: 13,
                            color: remaining > 0 ? const Color(0xFFF97316) : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'PENDING BALANCE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                       ),
                       const SizedBox(height: 6),
                       Text(
                         currency.format(remaining),
                         style: TextStyle(
                           fontSize: 14.5,
                           fontWeight: FontWeight.w800,
                           color: isDark ? Colors.white : Colors.orange.shade900,
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ],
       ),
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
    _StepData('In Review', ProjectStatus.reviewPending, 'Client is reviewing the video drafts'),
    _StepData('Working on feedback', ProjectStatus.revisionPending, 'Freelancer is working on requested changes'),
    _StepData('Completed', ProjectStatus.completed, 'Work done, payment pending'),
    _StepData('Paid', ProjectStatus.paid, 'Fully paid and closed'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((s) => s.status == currentStatus);
    if (currentIndex < 0) return const SizedBox.shrink();

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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Icon(CupertinoIcons.arrow_branch, size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PROJECT PIPELINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${currentIndex + 1} / ${_steps.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              index: i,
              currentIndex: currentIndex,
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
    required int index,
    required int currentIndex,
    VoidCallback? onTap,
  }) {
    const green = Color(0xFF10B981);
    const blue = AppColors.primary;
    final muted = AppColors.textMuted.withValues(alpha: 0.4);

    final dotColor = isCompleted ? green : isCurrent ? blue : muted;
    final cardBg = isCurrent
        ? blue.withValues(alpha: 0.06)
        : isCompleted
            ? green.withValues(alpha: 0.04)
            : (isDark ? AppColors.card : Colors.white);
    final cardBorder = isCurrent
        ? blue.withValues(alpha: 0.25)
        : isCompleted
            ? green.withValues(alpha: 0.15)
            : (isDark ? AppColors.border : const Color(0xFFE2E8F0));
    final titleColor = isCompleted || isCurrent
        ? (isDark ? AppColors.textPrimary : const Color(0xFF0F172A))
        : AppColors.textMuted;
    final hintColor = isCurrent
        ? blue.withValues(alpha: 0.7)
        : isCompleted
            ? green.withValues(alpha: 0.6)
            : AppColors.textMuted;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // timeline column
            SizedBox(
              width: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: 2,
                          color: index == 0
                              ? Colors.transparent
                              : (index <= currentIndex
                                  ? (index - 1 < currentIndex ? green.withValues(alpha: 0.4) : blue.withValues(alpha: 0.4))
                                  : (isDark ? AppColors.border : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isLast
                              ? Colors.transparent
                              : (index < currentIndex
                                  ? green.withValues(alpha: 0.4)
                                  : (isDark ? AppColors.border : const Color(0xFFE2E8F0))),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: isCurrent ? 14.0 : 10.0,
                    height: isCurrent ? 14.0 : 10.0,
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            // step card
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder, width: 0.8),
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
                                  fontSize: 13.5,
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                step.hint,
                                style: TextStyle(fontSize: 11, color: hintColor, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: green),
                                SizedBox(width: 3),
                                Text('Done', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: green)),
                              ],
                            ),
                          ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.pencil, size: 10, color: blue),
                                SizedBox(width: 3),
                                Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: blue)),
                              ],
                            ),
                          ),
                        if (!isCompleted && !isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Next', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted.withValues(alpha: 0.6))),
                                const SizedBox(width: 2),
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
