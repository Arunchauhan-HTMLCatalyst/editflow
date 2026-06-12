import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/client_provider.dart';
import '../widgets/client_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_layout.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/providers/computed_providers.dart';
import '../../settings/providers/settings_provider.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = '';

  Widget _buildFreelancersList(List<TopFreelancerEntry> freelancers, double padding) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = freelancers
        .where((f) => f.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline_rounded,
        title: _searchQuery.isNotEmpty
            ? 'No freelancers found'
            : 'No freelancers yet',
        subtitle: _searchQuery.isNotEmpty
            ? 'Try a different search'
            : 'Projects assigned to you will show their freelancers here.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final f = filtered[index];
        final initials = f.name.isNotEmpty
            ? f.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
            : '?';

        return AnimatedListItem(
          index: index,
          child: GestureDetector(
            onTap: () => context.push('/freelancers/${f.id}'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              boxShadow: isDark
                  ? []
                  : [
                      const BoxShadow(
                        color: Color(0x0C0F172A),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      )
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primaryNeon.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${f.activeProjectsCount} active projects',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (f.nextDeadline != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Next Deadline',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, yyyy').format(f.nextDeadline!),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: f.nextDeadline!.isBefore(DateTime.now())
                              ? AppColors.error
                              : AppColors.primaryNeon,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientProvider);
    final clientDataList = ref.watch(clientListDataProvider);
    final currency = ref.watch(currencyProvider);
    final padding = AppLayout.pagePadding(context);
    final columns = AppLayout.gridColumns(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClient = ref.watch(settingsProvider).isClientMode;
    final freelancersList = ref.watch(dashboardMetricsProvider).topFreelancers;

    final headerTitle = isClient ? 'Freelancers' : 'Clients';
    final subtitleCount = isClient
        ? '${freelancersList.length} ${freelancersList.length == 1 ? 'freelancer' : 'freelancers'} total'
        : '${clientDataList.length} ${clientDataList.length == 1 ? 'client' : 'clients'} total';

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16.0, padding, 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: AppTextStyles.title1(isDark).copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleCount,
                        style: AppTextStyles.caption(isDark).copyWith(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (!isClient)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface : CupertinoColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.add,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () => context.push('/add-client'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 8.0, padding, 16.0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: isClient ? 'Search freelancers...' : 'Search clients...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: isClient
                ? _buildFreelancersList(freelancersList, padding)
                : clientsAsync.when(
              loading: () => LoadingWidget(message: 'Loading clients...'),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.read(clientProvider.notifier).refresh(),
              ),
              data: (_) {
                final filtered = clientDataList
                    .where((d) =>
                        d.client.name.toLowerCase().contains(_searchQuery) ||
                        (d.client.company?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (d.client.email?.toLowerCase().contains(_searchQuery) ?? false))
                    .toList();

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: _searchQuery.isNotEmpty
                        ? 'No clients found'
                        : 'No clients yet',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try a different search'
                        : 'Add your first client to get started',
                    actionLabel: 'Add Client',
                    onAction: () => context.push('/add-client'),
                  );
                }

                if (columns > 1) {
                  return GridView.builder(
                    padding: EdgeInsets.all(padding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: columns == 2 ? 1.6 : 1.8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final d = filtered[index];
                      return AnimatedListItem(
                        index: index,
                        child: RepaintBoundary(
                          child: ClientCard(
                            client: d.client,
                            onTap: () => context.push('/clients/${d.client.id}'),
                            totalRevenue: d.revenue,
                            pendingRevenue: d.pending,
                            projectCount: d.projectCount,
                            currency: currency,
                          ),
                        ),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(padding),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final d = filtered[index];
                    return AnimatedListItem(
                      index: index,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ClientCard(
                          client: d.client,
                          onTap: () => context.push('/clients/${d.client.id}'),
                          totalRevenue: d.revenue,
                          pendingRevenue: d.pending,
                          projectCount: d.projectCount,
                          currency: currency,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
