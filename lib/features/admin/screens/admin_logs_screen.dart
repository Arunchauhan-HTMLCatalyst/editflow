import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    // The adminStatsProvider already returns the latest activities list!
    final statsAsync = ref.watch(adminStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All Logs', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Projects', 'project'),
              const SizedBox(width: 8),
              _buildFilterChip('Comments', 'comment'),
              const SizedBox(width: 8),
              _buildFilterChip('Status Updates', 'status'),
              const SizedBox(width: 8),
              _buildFilterChip('Reviews', 'review'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Logs Display Terminal
        Expanded(
          child: statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
            data: (data) {
              final activities = data['recentActivity'] as List? ?? [];
              
              // Apply local filters based on description or type keys
              final filteredLogs = activities.where((act) {
                if (_selectedFilter == 'all') return true;
                
                final type = (act['type'] as String? ?? '').toLowerCase();
                final desc = (act['description'] as String? ?? '').toLowerCase();
                
                if (_selectedFilter == 'project') {
                  return type.contains('project') || desc.contains('project');
                }
                if (_selectedFilter == 'comment') {
                  return type.contains('comment') || desc.contains('comment');
                }
                if (_selectedFilter == 'status') {
                  return type.contains('status') || desc.contains('status') || desc.contains('changed');
                }
                if (_selectedFilter == 'review') {
                  return type.contains('review') || desc.contains('review');
                }
                return true;
              }).toList();

              if (filteredLogs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: const Center(
                    child: Text('No system logs found matching this filter.', style: TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: ListView.separated(
                  itemCount: filteredLogs.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, idx) {
                    final log = filteredLogs[idx];
                    final description = log['description'] as String? ?? '';
                    final type = log['type'] as String? ?? 'general';
                    final userId = log['user_id'] as String? ?? 'system';
                    final dt = DateTime.parse(log['created_at'] as String);
                    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Terminal prefix
                          const Text(
                            '\$ ',
                            style: TextStyle(fontFamily: 'Courier', color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontFamily: 'Courier',
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.border,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontFamily: 'Courier',
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'User: $userId',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontFamily: 'Courier',
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formattedTime,
                            style: const TextStyle(fontSize: 11, fontFamily: 'Courier', color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.card,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }
}
