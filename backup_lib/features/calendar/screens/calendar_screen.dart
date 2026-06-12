import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/models/project.dart';
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
        loading: () => Center(child: CircularProgressIndicator()),
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.sm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                }),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: AppTextStyles.title2(widget.isDark),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                }),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
              child: Center(
                child: Text(d, style: AppTextStyles.small(widget.isDark)),
              ),
            )).toList(),
          ),
          SizedBox(height: AppSpacing.sm),

          Wrap(
            children: <Widget>[
              ...List.generate(firstWeekday, (_) => Container(
                width: (MediaQuery.of(context).size.width - 32) / 7,
                height: 44,
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
              final isPast = date.isBefore(DateTime.now().subtract(Duration(days: 1)));

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  width: (MediaQuery.of(context).size.width - 32) / 7,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : isToday
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isPast
                              ? AppColors.textMuted
                              : isSelected
                                  ? AppColors.primary
                                  : widget.isDark
                                      ? AppColors.textPrimary
                                      : Color(0xFF18181B),
                        ),
                      ),
                      if (hasDeadline)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            ],
          ),
          SizedBox(height: AppSpacing.xl),

          if (_selectedDate != null) ...[
            Text(
              DateFormat('MMMM d, yyyy').format(_selectedDate!),
              style: AppTextStyles.title3(widget.isDark),
            ),
            SizedBox(height: AppSpacing.md),
            if (dayProjects.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Text('No deadlines on this day', style: AppTextStyles.small(widget.isDark)),
                ),
              )
            else
              ...dayProjects.map((p) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  child: InkWell(
                    onTap: () => context.push('/projects/${p.id}'),
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.cardPadding),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: AppTextStyles.label(widget.isDark)),
                                if (p.clientName != null)
                                  Text(p.clientName!, style: AppTextStyles.small(widget.isDark)),
                              ],
                            ),
                          ),
                          Text(
                            widget.currency.format(p.price),
                            style: AppTextStyles.label(widget.isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }
}
