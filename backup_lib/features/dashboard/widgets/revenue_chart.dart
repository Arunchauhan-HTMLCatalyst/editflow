import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum ChartPeriod { week, month, year }

class RevenueChart extends StatefulWidget {
  final List<double> weeklyData;
  final List<double> monthlyData;
  final List<double> yearlyData;
  final String Function(double) formatValue;

  const RevenueChart({
    super.key,
    required this.weeklyData,
    required this.monthlyData,
    required this.yearlyData,
    required this.formatValue,
  });

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  ChartPeriod _period = ChartPeriod.month;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _getData();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Revenue', style: AppTextStyles.title3(isDark)),
                Row(
                  children: [
                    _PeriodTab(
                      label: '7D',
                      selected: _period == ChartPeriod.week,
                      isDark: isDark,
                      onTap: () => setState(() => _period = ChartPeriod.week),
                    ),
                    SizedBox(width: 2),
                    _PeriodTab(
                      label: '30D',
                      selected: _period == ChartPeriod.month,
                      isDark: isDark,
                      onTap: () => setState(() => _period = ChartPeriod.month),
                    ),
                    SizedBox(width: 2),
                    _PeriodTab(
                      label: '12M',
                      selected: _period == ChartPeriod.year,
                      isDark: isDark,
                      onTap: () => setState(() => _period = ChartPeriod.year),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: data.isEmpty || data.every((d) => d == 0)
                  ? Center(
                      child: Text('No data', style: AppTextStyles.small(isDark)),
                    )
                  : _ChartBody(data: data, formatValue: widget.formatValue, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _getData() {
    switch (_period) {
      case ChartPeriod.week:
        return widget.weeklyData;
      case ChartPeriod.month:
        return widget.monthlyData;
      case ChartPeriod.year:
        return widget.yearlyData;
    }
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : (isDark ? AppColors.textMuted : Color(0xFF71717A)),
          ),
        ),
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  final List<double> data;
  final String Function(double) formatValue;
  final bool isDark;

  const _ChartBody({
    required this.data,
    required this.formatValue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppColors.border : Color(0xFFE4E4E7)).withValues(alpha: 0.4),
            strokeWidth: 0.5,
          ),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.chartLine,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chartArea,
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              return LineTooltipItem(
                formatValue(spot.y),
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
