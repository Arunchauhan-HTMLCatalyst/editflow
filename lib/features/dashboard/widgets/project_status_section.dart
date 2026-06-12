import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../projects/models/project_status.dart';
import '../../../shared/constants/status_colors.dart';

class ProjectStatusSection extends StatelessWidget {
  final Map<ProjectStatus, int> statusData;
  final int total;

  const ProjectStatusSection({
    super.key,
    required this.statusData,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Project Status', style: AppTextStyles.title3(isDark)),
                  Text(
                    '$total total',
                    style: AppTextStyles.small(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: _sections(isDark),
                          centerSpaceRadius: 28,
                          sectionsSpace: 2,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(enabled: false),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ProjectStatus.values
                            .where((s) => (statusData[s] ?? 0) > 0)
                            .map((s) => _StatusLegend(
                                  color: _statusColor(s),
                                  label: s.displayName,
                                  count: statusData[s] ?? 0,
                                  isDark: isDark,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _sections(bool isDark) {
    return ProjectStatus.values
        .where((s) => (statusData[s] ?? 0) > 0)
        .map((s) {
      final count = statusData[s] ?? 0;
      final percentage = total > 0 ? (count / total * 100) : 0.0;
      return PieChartSectionData(
        color: _statusColor(s),
        value: percentage,
        title: '',
        radius: 32,
      );
    }).toList();
  }

  Color _statusColor(ProjectStatus status) => statusColor(status);
}

class _StatusLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool isDark;

  const _StatusLegend({
    required this.color,
    required this.label,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption(isDark).copyWith(
                fontSize: 12.5,
              ),
            ),
          ),
          Text(
            '$count',
            style: AppTextStyles.label(isDark).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
