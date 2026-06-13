import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
import '../../projects/models/project_status.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _isSelectMode = false;
  final Set<String> _selectedProjectIds = {};

  void _shareInvoiceText(Project project, CurrencyConfig currency) {
    final buffer = StringBuffer();
    buffer.writeln('================================================');
    buffer.writeln('               E D I T F L O W                  ');
    buffer.writeln('               INVOICE SUMMARY                  ');
    buffer.writeln('================================================');
    buffer.writeln('  Invoice Ref : #EF-${project.id.substring(0, 8).toUpperCase()}');
    buffer.writeln('  Date        : ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('  BILLED BY:');
    buffer.writeln('  Independent Video Creative / Editor');
    buffer.writeln('');
    buffer.writeln('  BILLED TO:');
    buffer.writeln('  ${project.clientName ?? 'Valued Client'}');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('  SERVICES & DESCRIPTION:');
    buffer.writeln('  • Video Production & Post-Production');
    buffer.writeln('    Project: ${project.name}');
    if (project.deadline != null) {
      buffer.writeln('    Deadline: ${DateFormat('yyyy-MM-dd').format(project.deadline!)}');
    }
    buffer.writeln('------------------------------------------------');
    buffer.writeln('  FINANCIAL SUMMARY:');
    buffer.writeln('  Total Budget     :  ${currency.format(project.price)}');
    buffer.writeln('  Received Amount  :  ${currency.format(project.receivedAmount)}');
    buffer.writeln('  --------------------------------------------');
    buffer.writeln('  BALANCE DUE      :  ${currency.format(project.remainingAmount)}');
    buffer.writeln('  PAYMENT STATUS   :  ${project.remainingAmount <= 0 ? "✓ PAID IN FULL" : "⚠ BALANCE OUTSTANDING"}');
    buffer.writeln('------------------------------------------------');

    final settings = ref.read(settingsProvider);
    if (settings.upiId.isNotEmpty && project.remainingAmount > 0) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final fullName = user?.userMetadata?['full_name'] as String?;
      String? rawName = fullName ?? user?.email?.split('@').first;
      String userName = 'User';
      if (rawName != null && rawName.isNotEmpty) {
        userName = rawName[0].toUpperCase() + rawName.substring(1);
      }
      
      final upiLink = _generateUpiLink(
        upiId: settings.upiId,
        payeeName: userName,
        amount: project.remainingAmount,
        transactionNote: 'Payment for #EF-${project.id.substring(0, 8).toUpperCase()}',
        currencyCode: currency.code,
      );
      
      buffer.writeln('  PAY TO UPI ID    :  ${settings.upiId}');
      buffer.writeln('  PAYMENT LINK     :  $upiLink');
      buffer.writeln('------------------------------------------------');
    }

    buffer.writeln('  Thank you for your business!');
    buffer.writeln('  If you have any questions, please contact me.');
    buffer.writeln('================================================');

    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Invoice for ${project.name}'));
  }

  void _shareCombinedInvoiceText(List<Project> projects, CurrencyConfig currency) {
    if (projects.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('--- COMBINED INVOICE ---');
    buffer.writeln('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    buffer.writeln('------------------------');

    double totalBudget = 0;
    double totalPaid = 0;

    for (int i = 0; i < projects.length; i++) {
      final p = projects[i];
      totalBudget += p.price;
      totalPaid += p.receivedAmount;
      buffer.writeln('${i + 1}. Project: ${p.name}');
      buffer.writeln('   Client: ${p.clientName ?? 'Valued Client'}');
      buffer.writeln('   Budget: ${currency.format(p.price)}');
      buffer.writeln('   Paid: ${currency.format(p.receivedAmount)}');
      buffer.writeln('   Remaining: ${currency.format(p.remainingAmount)}');
      buffer.writeln('------------------------');
    }

    final totalRemaining = totalBudget - totalPaid;
    buffer.writeln('SUMMARY:');
    buffer.writeln('Total Combined Budget: ${currency.format(totalBudget)}');
    buffer.writeln('Total Paid: ${currency.format(totalPaid)}');
    buffer.writeln('Total Remaining Balance: ${currency.format(totalRemaining)}');
    buffer.writeln('------------------------');

    final settings = ref.read(settingsProvider);
    if (settings.upiId.isNotEmpty && totalRemaining > 0) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final fullName = user?.userMetadata?['full_name'] as String?;
      String? rawName = fullName ?? user?.email?.split('@').first;
      String userName = 'User';
      if (rawName != null && rawName.isNotEmpty) {
        userName = rawName[0].toUpperCase() + rawName.substring(1);
      }
      
      final upiLink = _generateUpiLink(
        upiId: settings.upiId,
        payeeName: userName,
        amount: totalRemaining,
        transactionNote: 'Combined Invoice Payment',
        currencyCode: currency.code,
      );
      
      buffer.writeln('Pay to UPI ID: ${settings.upiId}');
      buffer.writeln('Payment Link: $upiLink');
      buffer.writeln('------------------------');
    }

    buffer.writeln('Thank you for your business!');
    buffer.writeln('Generated via EditFlow');

    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Combined Invoice'));
  }

  void _showInvoicePreview(BuildContext context, {Project? project, List<Project>? projects, required CurrencyConfig currency}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _InvoicePreviewSheet(
          project: project,
          projects: projects,
          currency: currency,
          isDark: isDark,
          onShareText: () {
            Navigator.pop(context);
            if (project != null) {
              _shareInvoiceText(project, currency);
            } else if (projects != null) {
              _shareCombinedInvoiceText(projects, currency);
            }
          },
        );
      },
    );
  }

  void _shareInvoice(Project project, CurrencyConfig currency) {
    _showInvoicePreview(context, project: project, currency: currency);
  }

  void _shareCombinedInvoice(List<Project> projects, CurrencyConfig currency) {
    _showInvoicePreview(context, projects: projects, currency: currency);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectProvider);
    final currency = ref.watch(currencyProvider);
    final overview = ref.watch(paymentOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20.0,
        title: _isSelectMode
            ? Text(
                '${_selectedProjectIds.length} Selected',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              )
            : Text(
                'Payments',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
        leading: _isSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectMode = false;
                    _selectedProjectIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (!_isSelectMode)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded),
              tooltip: 'Select multiple projects',
              onPressed: () {
                setState(() {
                  _isSelectMode = true;
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: () {
                final projects = projectsAsync.valueOrNull ?? [];
                setState(() {
                  _selectedProjectIds.addAll(projects.map((p) => p.id));
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share combined invoice',
              onPressed: _selectedProjectIds.isEmpty
                  ? null
                  : () {
                      final projects = projectsAsync.valueOrNull ?? [];
                      final selected = projects.where((p) => _selectedProjectIds.contains(p.id)).toList();
                      _shareCombinedInvoice(selected, currency);
                    },
            ),
          ]
        ],
      ),
      body: projectsAsync.when(
        loading: () => const LoadingWidget(message: 'Loading payments...'),
        error: (e, _) => Center(
          child: Text('Error: ${e.toString()}'),
        ),
        data: (projects) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: AppTextStyles.title2(isDark).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total budget',
                        value: currency.format(overview.totalAmount),
                        color: AppColors.primary,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Advance paid',
                        value: currency.format(overview.receivedAmount),
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Remaining balance',
                        value: currency.format(overview.remaining),
                        color: AppColors.warning,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Paid projects',
                        value: '${overview.paidProjects.length}',
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (overview.overdueProjects.isNotEmpty && !_isSelectMode) ...[
                  Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        'Overdue Payments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...overview.overdueProjects.map((p) => RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _OverdueCard(project: p, isDark: isDark, currency: currency),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                Text(
                  'All Projects',
                  style: AppTextStyles.title3(isDark).copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (projects.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.attach_money,
                    title: 'No payments yet',
                    subtitle: 'Create a project to start tracking payments',
                  )
                else
                  ...projects.map((p) {
                    final isSelected = _selectedProjectIds.contains(p.id);
                    return RepaintBoundary(
                      key: ValueKey(p.id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _PaymentProjectCard(
                          project: p,
                          isDark: isDark,
                          currency: currency,
                          isSelectMode: _isSelectMode,
                          isSelected: isSelected,
                          onSelectedChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedProjectIds.add(p.id);
                              } else {
                                _selectedProjectIds.remove(p.id);
                              }
                            });
                          },
                          onSharePressed: () => _shareInvoice(p, currency),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isDark ? AppColors.card : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.45)
                : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
            width: _isHovered ? 1.2 : 0.8,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: isDark 
                    ? AppColors.primary.withValues(alpha: 0.2) 
                    : const Color(0x0C0F172A),
                blurRadius: isDark ? 8 : 6,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: isDark ? Colors.transparent : const Color(0x020F172A),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final Project project;
  final bool isDark;
  final CurrencyConfig currency;

  const _OverdueCard({required this.project, required this.isDark, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              CupertinoIcons.alarm_fill, 
              size: 18, 
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currency.format(project.remainingAmount)} overdue',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.calendar,
                  size: 12,
                  color: AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d').format(project.deadline!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProjectCard extends StatefulWidget {
  final Project project;
  final bool isDark;
  final CurrencyConfig currency;
  final bool isSelectMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onSharePressed;

  const _PaymentProjectCard({
    required this.project,
    required this.isDark,
    required this.currency,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onSharePressed,
  });

  @override
  State<_PaymentProjectCard> createState() => _PaymentProjectCardState();
}

class _PaymentProjectCardState extends State<_PaymentProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final project = widget.project;
    final currency = widget.currency;
    final isSelectMode = widget.isSelectMode;
    final isSelected = widget.isSelected;
    final onSelectedChanged = widget.onSelectedChanged;
    final onSharePressed = widget.onSharePressed;

    final progress = project.price > 0
        ? (project.receivedAmount / project.price * 100).toStringAsFixed(0)
        : '0';

    final isPaid = project.status == ProjectStatus.paid;

    Widget cardContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? (isDark ? 6.0 : 4.0) : (isDark ? 0 : 2.0),
          shadowColor: isDark
              ? (_isHovered ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent)
              : const Color(0x0C0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : (_isHovered
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : (isDark ? AppColors.border : const Color(0xFFE2E8F0))),
              width: isSelected ? 1.5 : (_isHovered ? 1.2 : 0.8),
            ),
          ),
          child: InkWell(
            onTap: () {
              if (isSelectMode) {
                if (onSelectedChanged != null) {
                  onSelectedChanged(!isSelected);
                }
              } else {
                context.push('/projects/${project.id}');
              }
            },
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          currency.format(project.remainingAmount),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPaid ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                      if (!isSelectMode) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Share Invoice',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onSharePressed,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surface : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                                    width: 0.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.share_rounded,
                                  size: 14,
                                  color: isDark ? AppColors.textPrimary : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currency.format(project.receivedAmount)} paid of ${currency.format(project.price)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$progress%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 6,
                      width: double.infinity,
                      color: isDark 
                          ? AppColors.border.withValues(alpha: 0.4) 
                          : const Color(0xFFE2E8F0),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (project.receivedAmount / project.price).clamp(0, 1),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isPaid ? AppColors.successGradient : AppColors.primaryGradient,
                            ),
                            boxShadow: [
                              if (_isHovered)
                                BoxShadow(
                                  color: (isPaid ? AppColors.success : AppColors.primary).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
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
          ),
        ),
      ),
    );

    if (isSelectMode) {
      return Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: onSelectedChanged,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(
              color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: cardContent),
        ],
      );
    }

    return cardContent;
  }
}

class _InvoicePreviewSheet extends ConsumerStatefulWidget {
  final Project? project;
  final List<Project>? projects;
  final CurrencyConfig currency;
  final bool isDark;
  final VoidCallback onShareText;

  const _InvoicePreviewSheet({
    this.project,
    this.projects,
    required this.currency,
    required this.isDark,
    required this.onShareText,
  });

  @override
  ConsumerState<_InvoicePreviewSheet> createState() => _InvoicePreviewSheetState();
}

class _InvoicePreviewSheetState extends ConsumerState<_InvoicePreviewSheet> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() {
      _isSharing = true;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = Directory.systemTemp;
      final fileName = widget.project != null
          ? 'invoice_${widget.project!.id.substring(0, 8)}.png'
          : 'combined_invoice_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      final settings = ref.read(settingsProvider);
      String shareText = 'Freelance Invoice';
      double totalRemaining = 0;
      if (widget.project != null) {
        totalRemaining = widget.project!.remainingAmount;
      } else if (widget.projects != null) {
        double totalBudget = 0;
        double totalPaid = 0;
        for (final p in widget.projects!) {
          totalBudget += p.price;
          totalPaid += p.receivedAmount;
        }
        totalRemaining = totalBudget - totalPaid;
      }
      
      if (settings.upiId.isNotEmpty && totalRemaining > 0) {
        final authState = ref.read(authProvider);
        final user = authState.user;
        final fullName = user?.userMetadata?['full_name'] as String?;
        String? rawName = fullName ?? user?.email?.split('@').first;
        String userName = 'User';
        if (rawName != null && rawName.isNotEmpty) {
          userName = rawName[0].toUpperCase() + rawName.substring(1);
        }
        
        final upiLink = _generateUpiLink(
          upiId: settings.upiId,
          payeeName: userName,
          amount: totalRemaining,
          transactionNote: widget.project != null
              ? 'Payment for #EF-${widget.project!.id.substring(0, 8).toUpperCase()}'
              : 'Combined Invoice Payment',
          currencyCode: widget.currency.code,
        );
        
        shareText = 'Freelance Invoice\nPay via UPI: $upiLink';
      }

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: shareText));
    } catch (e) {
      debugPrint('Error sharing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingSection(String header, String info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          info,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: widget.isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceRow(String title, String desc, String cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            cost,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    final isSingle = widget.project != null;
    final settings = ref.watch(settingsProvider);
    final refCode = isSingle
        ? '#EF-${widget.project!.id.substring(0, 8).toUpperCase()}'
        : '#EF-COMB-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final fullName = user?.userMetadata?['full_name'] as String?;
    String? rawName = fullName ?? user?.email?.split('@').first;
    String userName = 'User';
    if (rawName != null && rawName.isNotEmpty) {
      userName = rawName[0].toUpperCase() + rawName.substring(1);
    }

    final clientNames = isSingle
        ? (widget.project!.clientName ?? 'Valued Client')
        : widget.projects!
            .map((p) => p.clientName)
            .where((name) => name != null && name.isNotEmpty)
            .toSet()
            .join(', ');
    final clientName = clientNames.isNotEmpty ? clientNames : 'Valued Client';

    double totalBudget = 0;
    double totalPaid = 0;

    if (isSingle) {
      totalBudget = widget.project!.price;
      totalPaid = widget.project!.receivedAmount;
    } else {
      for (final p in widget.projects!) {
        totalBudget += p.price;
        totalPaid += p.receivedAmount;
      }
    }
    final totalRemaining = totalBudget - totalPaid;
    final isPaid = totalRemaining <= 0;

    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const AppLogo(size: 36, borderRadius: 8),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EDITFLOW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'INVOICE RECEIPT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 12,
                      color: isPaid ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaid ? 'PAID IN FULL' : 'UNPAID BALANCE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isPaid ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
            color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('Invoice Reference', refCode),
              _buildMetaItem('Date', DateFormat('yyyy-MM-dd').format(DateTime.now())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildBillingSection('Billed By', userName)),
              const SizedBox(width: 16),
              Expanded(child: _buildBillingSection('Billed To', clientName)),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
            color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
            height: 1,
          ),
          const SizedBox(height: 16),
          Text(
            'SERVICES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          if (isSingle)
            _buildServiceRow(
              widget.project!.name,
              'Video Production & Post-Production',
              widget.currency.format(widget.project!.price),
            )
          else
            ...widget.projects!.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildServiceRow(
                    p.name,
                    p.clientName ?? 'Client',
                    widget.currency.format(p.price),
                  ),
                )),
          const SizedBox(height: 16),
          // Total Budget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Budget:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
              Text(
                widget.currency.format(totalBudget),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Received Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Received Amount:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
              Text(
                widget.currency.format(totalPaid),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Balance Due Highlight Container (Full Width)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPaid
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BALANCE DUE:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.currency.format(totalRemaining),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isPaid ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          // Centered QR Code for UPI Payment if configured & unpaid
          if (settings.upiId.isNotEmpty && totalRemaining > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'UPI PAYMENT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: widget.isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: QrImageView(
                      data: _generateUpiLink(
                        upiId: settings.upiId,
                        payeeName: userName,
                      ),
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      size: 110.0,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      embeddedImage: const AssetImage('assets/images/app_logo_qr.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(22, 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'SCAN TO PAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settings.upiId,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Future<void> _checkAndShare(VoidCallback onProceed) async {
    final settings = ref.read(settingsProvider);
    if (settings.upiId.isEmpty) {
      if (!mounted) return;
      final String? result = await showDialog<String>(
        context: context,
        builder: (ctx) => _AddUpiDialog(isDark: widget.isDark),
      );
      if (result == null) {
        return;
      }
      if (result == 'bypass') {
        onProceed();
      } else {
        await ref.read(settingsProvider.notifier).setUpiId(result);
        onProceed();
      }
    } else {
      onProceed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.surface : const Color(0xFFF4FDFB),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.border : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title and Close Button Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Share Invoice',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: widget.isDark ? AppColors.textSecondary : const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Scrollable Card content only
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _buildInvoiceCard(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          // Fixed Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.image_rounded, size: 18),
                  label: Text(
                    _isSharing ? 'Generating...' : 'Share Image',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: _isSharing ? null : () => _checkAndShare(_shareImage),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: widget.isDark ? AppColors.border : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.text_fields_rounded, size: 18),
                  label: const Text(
                    'Share Text',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: _isSharing
                      ? null
                      : () => _checkAndShare(() {
                            widget.onShareText();
                          }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _generateUpiLink({
  required String upiId,
  required String payeeName,
  double? amount,
  String? transactionNote,
  String? currencyCode,
}) {
  final cleanUpi = upiId.trim();
  final cleanName = Uri.encodeComponent(payeeName.trim());
  
  return 'upi://pay?pa=$cleanUpi&pn=$cleanName';
}

class _AddUpiDialog extends StatefulWidget {
  final bool isDark;

  const _AddUpiDialog({required this.isDark});

  @override
  State<_AddUpiDialog> createState() => _AddUpiDialogState();
}

class _AddUpiDialogState extends State<_AddUpiDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add UPI ID',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Receive direct payments by adding your UPI ID. We will generate custom payment links for your clients.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. yourname@bank',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.error,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.error,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'UPI ID is required';
                  }
                  final upiRegex = RegExp(r'^[\w\.\-_]{2,256}@[\w]{2,64}$');
                  if (!upiRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid UPI ID (e.g. user@bank)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                        side: BorderSide(
                          color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop('bypass');
                      },
                      child: const Text(
                        'Share without UPI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.of(context).pop(_controller.text.trim());
                        }
                      },
                      child: const Text(
                        'Save & Share',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
