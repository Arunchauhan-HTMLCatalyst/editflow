import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
import '../../projects/models/project_status.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/currency_config.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectProvider);
    final deadlines = ref.watch(calendarDeadlinesProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (_) => _CalendarView(deadlines: deadlines, isDark: isDark, currency: currency),
        ),
      ),
    );
  }
}

class _CalendarView extends StatefulWidget {
  final List<Project> deadlines;
  final bool isDark;
  final CurrencyConfig currency;

  const _CalendarView({required this.deadlines, required this.isDark, required this.currency});

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final today = DateTime.now();

    final dayProjects = _selectedDate != null
        ? widget.deadlines.where((p) =>
            p.deadline!.year == _selectedDate!.year &&
            p.deadline!.month == _selectedDate!.month &&
            p.deadline!.day == _selectedDate!.day)
        : <Project>[];

    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate cell width dynamically based on card padding (20 screen padding + 16 card padding)
    final gridWidth = screenWidth - 40 - 32;
    final cellWidth = gridWidth / 7;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Navigation controls
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: AppTextStyles.title2(widget.isDark).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Today Button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
                    _selectedDate = DateTime.now();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Prev Button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                }),
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.surface : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 14,
                    color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Next Button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                }),
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.surface : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: widget.isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Wrap in a Premium Calendar Grid Card
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                children: [
                  // Days of the week header
                  Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isDark ? AppColors.textMuted : const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    children: <Widget>[
                      ...List.generate(firstWeekday, (_) => SizedBox(
                        width: cellWidth,
                        height: 48,
                      )),
                      ...List.generate(daysInMonth, (i) {
                        final day = i + 1;
                        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                        final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                        final isSelected = _selectedDate != null &&
                            date.year == _selectedDate!.year &&
                            date.month == _selectedDate!.month &&
                            date.day == _selectedDate!.day;
                        final hasDeadline = widget.deadlines.any((p) =>
                            p.deadline!.year == date.year &&
                            p.deadline!.month == date.month &&
                            p.deadline!.day == date.day);
                        final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                        return _CalendarDayCell(
                          day: day,
                          isToday: isToday,
                          isSelected: isSelected,
                          hasDeadline: hasDeadline,
                          isPast: isPast,
                          isDark: widget.isDark,
                          width: cellWidth,
                          onTap: () => setState(() => _selectedDate = date),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          if (_selectedDate != null) ...[
            Text(
              DateFormat('MMMM d, yyyy').format(_selectedDate!),
              style: AppTextStyles.title3(widget.isDark).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            if (dayProjects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    'No deadlines on this day',
                    style: AppTextStyles.small(widget.isDark).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              ...dayProjects.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: _AgendaProjectItem(
                      project: p,
                      isDark: widget.isDark,
                      currency: widget.currency,
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasDeadline;
  final bool isPast;
  final bool isDark;
  final VoidCallback onTap;
  final double width;

  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasDeadline,
    required this.isPast,
    required this.isDark,
    required this.onTap,
    required this.width,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isToday = widget.isToday;
    final isDark = widget.isDark;

    Color? cellBg;
    Border? cellBorder;

    if (isSelected) {
      cellBg = AppColors.primary;
    } else if (isToday) {
      cellBg = AppColors.primary.withValues(alpha: 0.12);
      cellBorder = Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.2);
    } else if (_isHovered) {
      cellBg = isDark ? AppColors.surface : const Color(0xFFF1F5F9);
      cellBorder = Border.all(color: isDark ? AppColors.border : const Color(0xFFE2E8F0), width: 0.8);
    }

    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (widget.isPast) {
      textColor = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);
    } else if (isToday) {
      textColor = AppColors.primary;
    } else {
      textColor = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(12),
            border: cellBorder,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              if (widget.hasDeadline)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppColors.warning,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.warning.withValues(alpha: 0.6),
                              blurRadius: 3,
                              spreadRadius: 0.5,
                            )
                          ],
                  ),
                )
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaProjectItem extends StatefulWidget {
  final Project project;
  final bool isDark;
  final CurrencyConfig currency;

  const _AgendaProjectItem({
    required this.project,
    required this.isDark,
    required this.currency,
  });

  @override
  State<_AgendaProjectItem> createState() => _AgendaProjectItemState();
}

class _AgendaProjectItemState extends State<_AgendaProjectItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final p = widget.project;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? (isDark ? 0 : 2.0) : 0,
          shadowColor: isDark ? Colors.transparent : const Color(0x0A0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
            side: BorderSide(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
              width: _isHovered ? 1.0 : 0.8,
            ),
          ),
          child: InkWell(
            onTap: () => context.push('/projects/${p.id}'),
            borderRadius: BorderRadius.circular(14.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: AppTextStyles.label(isDark).copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.clientName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              p.clientName!,
                              style: AppTextStyles.small(isDark).copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.currency.format(p.price),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _statusColor(p.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            p.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.paid:
        return AppColors.success;
      case ProjectStatus.inProgress:
        return AppColors.primary;
      case ProjectStatus.yetToStart:
        return AppColors.textMuted;
      default:
        return AppColors.warning;
    }
  }
}
