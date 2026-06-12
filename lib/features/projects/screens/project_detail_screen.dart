import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../providers/project_provider.dart';
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
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
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
      data: (project) {
        final p = project;
        final oldCached = _cachedProject;
        _cachedProject = p;

        if (_isEditing && oldCached != null && p != oldCached) {
          _populateControllers(p);
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
            actions: isClient
                ? []
                : (_isEditing
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
                              color: isDark ? AppColors.surface : CupertinoColors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
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
                            child: Icon(
                              CupertinoIcons.trash,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                          onPressed: () => _deleteProject(p),
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
                      ]),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: _isEditing
                ? _buildEditForm(isDark, p)
                : _buildDetail(isDark, p, currency, isClient),
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
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.statValue(isDark).copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildDetail(bool isDark, Project project, CurrencyConfig currency, bool isClient) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero header card
        Card(
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent top bar
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                    gradient: LinearGradient(colors: AppColors.primaryGradient),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project name
                      Text(
                        project.name,
                        style: AppTextStyles.title1(isDark).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Client / Freelancer row
                      if (displayName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                showFreelancer ? 'Freelancer: $displayName' : 'Client: $displayName',
                                style: AppTextStyles.body(isDark).copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(height: 14),
                      // Amount + Status row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _miniStat('Total budget', currency.format(project.price), isDark),
                                const SizedBox(height: 8),
                                _miniStat('Advance paid', currency.format(project.receivedAmount), isDark),
                                const SizedBox(height: 8),
                                _miniStat('Remaining balance', currency.format(project.remainingAmount), isDark),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(status: project.status),
                              if (project.deadline != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.calendar,
                                      size: 13,
                                      color: overdue ? AppColors.error : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(project.deadline!),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: overdue ? AppColors.error : AppColors.textSecondary,
                                      ),
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

        // Details title
        Text(
          'Details',
          style: AppTextStyles.caption(isDark).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
              if (project.description != null && project.description!.isNotEmpty)
                _detailBlock(isDark, CupertinoIcons.doc_text, 'Description', project.description!),
              if (project.description != null && project.description!.isNotEmpty && project.deadline != null)
                Divider(height: 1, color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
              if (project.deadline != null)
                _detailBlock(isDark, CupertinoIcons.calendar, 'Deadline',
                    DateFormat('MMM d, yyyy').format(project.deadline!)),
              Divider(height: 1, color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
              _detailBlock(isDark, CupertinoIcons.time, 'Created on',
                  DateFormat('MMM d, yyyy').format(project.createdAt)),
              Divider(height: 1, color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
              _detailBlock(isDark, CupertinoIcons.refresh, 'Last updated',
                  DateFormat('MMM d, yyyy').format(project.updatedAt)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCommentsSection(isDark, project),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _detailBlock(bool isDark, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
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
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        commentsAsync.when(
          data: (comments) {
            return Container(
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
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No feedback comments yet.',
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final timeStr = DateFormat('MMM d, h:mm a').format(comment.createdAt.toLocal());
                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: comment.userId == project.userId
                                              ? (isDark ? AppColors.primary.withAlpha(38) : AppColors.primary.withAlpha(26))
                                              : (isDark ? Colors.teal.withAlpha(38) : Colors.teal.withAlpha(26)),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: comment.userId == project.userId
                                                ? AppColors.primary.withAlpha(77)
                                                : Colors.teal.withAlpha(77),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          comment.userId == project.userId ? 'Freelancer' : 'Client',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: comment.userId == project.userId
                                                ? AppColors.primary
                                                : (isDark ? Colors.tealAccent : Colors.teal.shade700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.content,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textSecondary : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(
                                color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                            ),
                            onSubmitted: (text) => _postComment(projectId, text),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: () => _postComment(projectId, _commentController.text),
                        ),
                      ],
                    ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Widget _buildEditForm(bool isDark, Project project) {
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
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _receivedController,
                decoration: const InputDecoration(labelText: 'Advance Payment'),
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
      ref.read(projectProvider.notifier).updateStatus(project.id, newStatus);
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Icon(CupertinoIcons.money_dollar_circle, size: 14, color: AppColors.success),
              ),
              const SizedBox(width: 8),
              Text(
                'Payment',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _statBlock('Received', currency.format(received), AppColors.success),
              const SizedBox(width: 16),
              _statBlock('Remaining', currency.format(remaining), isDark ? AppColors.textPrimary : const Color(0xFF0F172A)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const Text('complete', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
                FractionallySizedBox(
                  widthFactor: (progress / 100).clamp(0, 1),
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: AppColors.successGradient),
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

  Widget _statBlock(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
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
    if (currentIndex < 0) return const SizedBox.shrink();

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
          const SizedBox(height: 20),
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
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // timeline column
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  const SizedBox(height: 6),
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
                  if (!isLast)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: isCompleted
                                ? green.withValues(alpha: 0.4)
                                : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
                          ),
                        ),
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
                    padding: const EdgeInsets.all(12.0),
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
