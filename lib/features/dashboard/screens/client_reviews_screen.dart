import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../projects/models/project.dart';
import '../../projects/models/project_status.dart';
import '../../projects/models/review_video.dart';
import '../../projects/providers/project_provider.dart';
import '../../projects/providers/review_provider.dart';
import '../../../shared/utils/video_source_provider.dart';

class ClientReviewsScreen extends ConsumerWidget {
  const ClientReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingReviewsAsync = ref.watch(clientPendingReviewsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20.0,
        title: const Text(
          'Pending Reviews',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: AmbientGlowContainer(
        child: SafeArea(
          child: pendingReviewsAsync.when(
            loading: () => ListView(
              padding: EdgeInsets.all(AppLayout.pagePadding(context)),
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ShimmerCard(height: 180, borderRadius: 20),
              )),
            ),
            error: (err, _) => Center(
              child: Text(
                'Failed to load reviews: $err',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (pendingProjects) {
              if (pendingProjects.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(AppLayout.pagePadding(context)),
                  child: Center(
                    child: EmptyStateWidget(
                      icon: CupertinoIcons.doc_text_viewfinder,
                      title: 'All Reviews Done!',
                      subtitle: 'You are completely caught up. No pending project reviews are awaiting your feedback.',
                    ),
                  ),
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppLayout.pagePadding(context),
                  8.0,
                  AppLayout.pagePadding(context),
                  AppLayout.pagePadding(context) + 24,
                ),
                itemCount: pendingProjects.length,
                itemBuilder: (context, index) {
                  final project = pendingProjects[index];
                  return _PendingReviewItemCard(
                    key: ValueKey('review_project_${project.id}'),
                    project: project,
                    isDark: isDark,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PendingReviewItemCard extends ConsumerWidget {
  final Project project;
  final bool isDark;

  const _PendingReviewItemCard({
    super.key,
    required this.project,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freelancerName = project.freelancerName ?? 'Freelancer';
    final initials = freelancerName.isNotEmpty
        ? freelancerName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    final latestReviewAsync = ref.watch(latestReviewProvider(project.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Freelancer Profile Block
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            initials.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        freelancerName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.hourglass, size: 10, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text(
                              'AWAITING REVIEW',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Project Title
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 0.8),
                  const SizedBox(height: 12),
                  
                  // Videos list
                  latestReviewAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Text(
                      'Error loading reviews: $err',
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                    data: (review) {
                      if (review == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Freelancer is preparing the review videos...',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                        );
                      }

                      final videosAsync = ref.watch(reviewVideosProvider(review.id));

                      return videosAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text(
                          'Error loading videos: $err',
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                        data: (videos) {
                          if (videos.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No videos uploaded for this review.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: videos.map((video) {
                              return _VideoReviewListTile(
                                key: ValueKey('review_video_${video.id}'),
                                project: project,
                                video: video,
                                isDark: isDark,
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoReviewListTile extends ConsumerWidget {
  final Project project;
  final ReviewVideo video;
  final bool isDark;

  const _VideoReviewListTile({
    super.key,
    required this.project,
    required this.video,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(reviewCommentsProvider(video.id));

    return commentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (comments) {
        final count = comments.length;
        return Container(
          margin: const EdgeInsets.only(top: 8.0),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: video.isApproved
                    ? Colors.green.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                video.isApproved ? Icons.check_circle_rounded : CupertinoIcons.play_fill,
                color: video.isApproved ? Colors.green : AppColors.primary,
                size: 13,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    video.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (video.isApproved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Approved',
                      style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                Text(
                  VideoSourceManager.getProviderName(video.url).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count comments added',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(
              CupertinoIcons.right_chevron,
              size: 13,
              color: AppColors.textMuted,
            ),
            onTap: () {
              context.push('/projects/${project.id}/reviews/${video.id}?isClient=true');
            },
          ),
        );
      },
    );
  }
}
