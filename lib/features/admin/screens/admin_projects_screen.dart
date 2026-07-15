import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';

class AdminProjectsScreen extends ConsumerStatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  ConsumerState<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends ConsumerState<AdminProjectsScreen> {
  String _searchQuery = '';

  Color _getStatusColor(String status) {
    switch (status) {
      case 'yet_to_start':
        return AppColors.textMuted;
      case 'in_progress':
        return AppColors.info;
      case 'revision_pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'paid':
        return AppColors.primaryNeon;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(adminProjectsProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              icon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
              hintText: 'Search projects by name, freelancer or client...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Projects List
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
            data: (projects) {
              // Client-side search filter
              final filtered = projects.where((p) {
                final name = (p['name'] as String? ?? '').toLowerCase();
                final freelancer = (p['profiles'] is Map ? (p['profiles']['full_name'] as String? ?? '') : '').toLowerCase();
                final client = (p['clients'] is Map ? (p['clients']['name'] as String? ?? '') : '').toLowerCase();
                return name.contains(_searchQuery) || freelancer.contains(_searchQuery) || client.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No projects match your query.', style: TextStyle(color: AppColors.textMuted)),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  final name = p['name'] as String? ?? 'Project';
                  final description = p['description'] as String? ?? 'No description';
                  final price = p['price'] ?? 0;
                  final received = p['received_amount'] ?? 0;
                  final status = p['status'] as String? ?? 'yet_to_start';
                  final deadlineStr = p['deadline'] as String?;
                  
                  final freelancer = p['profiles'] is Map ? p['profiles'] : null;
                  final freelancerName = freelancer != null ? (freelancer['full_name'] as String? ?? 'Deleted User') : 'None';
                  
                  final client = p['clients'] is Map ? p['clients'] : null;
                  final clientName = client != null ? (client['name'] as String? ?? 'Deleted Client') : 'None';
                  final clientCompany = client != null ? (client['company'] as String? ?? '') : '';

                  final formattedDeadline = deadlineStr != null
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(deadlineStr))
                      : 'No deadline';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.toUpperCase().replaceAll('_', ' '),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              
                              // Metadata Row
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_rounded, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Freelancer: $freelancerName',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.handshake_rounded, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Client: $clientName${clientCompany.isNotEmpty ? " ($clientCompany)" : ""}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Deadline: $formattedDeadline',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Financial Info
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹$price',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paid: ₹$received',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: received >= price ? AppColors.primaryNeon : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
