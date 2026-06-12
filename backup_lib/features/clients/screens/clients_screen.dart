import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/client_provider.dart';
import '../widgets/client_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientProvider);
    final clientDataList = ref.watch(clientListDataProvider);
    final currency = ref.watch(currencyProvider);
    final padding = AppLayout.pagePadding(context);
    final columns = AppLayout.gridColumns(context);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, AppSpacing.sm, padding, 0),
            child: Row(
              children: [
                Text('Clients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? AppColors.textPrimary : const Color(0xFF18181B))),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.add_rounded, color: AppColors.primary),
                  onPressed: () => context.push('/add-client'),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(padding, AppSpacing.xs, padding, AppSpacing.sm),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: clientsAsync.when(
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
