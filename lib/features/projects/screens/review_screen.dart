import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/video_source_provider.dart';
import '../models/review.dart';
import '../models/review_video.dart';
import '../models/review_comment.dart';
import '../providers/project_provider.dart';
import '../models/project_status.dart';
import '../providers/review_provider.dart';
import '../../../services/supabase_service.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String videoId;
  final bool isClient;

  const ReviewScreen({
    super.key,
    required this.projectId,
    required this.videoId,
    required this.isClient,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  VideoPlayerController? _controller;
  bool _isPlayerInitialized = false;
  bool _hasPlayerError = false;
  late final ValueNotifier<Duration> _currentPositionNotifier;
  Duration _totalDuration = Duration.zero;
  Timer? _positionTimer;
  bool _isDragging = false;
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentPositionNotifier = ValueNotifier<Duration>(Duration.zero);
    _commentFocusNode.addListener(_onFocusChange);
    _loadProjectAndVideo();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProjectAndVideo() async {
    // 1. Fetch video details first to get the URL
    try {
      final response = await SupabaseService.instance
          .from('review_videos')
          .select('*')
          .eq('id', widget.videoId)
          .single()
          .timeout(const Duration(seconds: 10));

      final video = ReviewVideo.fromJson(response);
      final playableUrl = VideoSourceManager.getPlayableUrl(video.url);

      _controller = VideoPlayerController.networkUrl(Uri.parse(playableUrl));
      
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
          _totalDuration = _controller!.value.duration;
        });

        _controller!.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('[ReviewScreen] Player initialization failed: $e');
      if (mounted) {
        setState(() {
          _hasPlayerError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;
    if (_controller != null && _controller!.value.isInitialized) {
      if (!_isDragging) {
        _currentPositionNotifier.value = _controller!.value.position;
      }
    }
  }

  @override
  void dispose() {
    _currentPositionNotifier.dispose();
    _positionTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _commentFocusNode.removeListener(_onFocusChange);
    _commentFocusNode.dispose();
    _commentInputController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _seekTo(Duration position) async {
    if (_controller != null && _isPlayerInitialized) {
      final wasPlaying = _controller!.value.isPlaying;
      await _controller!.seekTo(position);
      await Future.delayed(const Duration(milliseconds: 50));
      if (wasPlaying && !_controller!.value.isPlaying) {
        await _controller!.play();
      }
      if (mounted) {
        _currentPositionNotifier.value = position;
      }
    }
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open URL in browser')),
        );
      }
    }
  }



  Future<void> _addCommentFromInput(Review review) async {
    final text = _commentInputController.text.trim();
    if (text.isEmpty) return;

    final currentMs = _currentPositionNotifier.value.inMilliseconds;
    final comment = ReviewComment(
      id: '',
      videoId: widget.videoId,
      timestampMs: currentMs,
      comment: text,
      authorId: SupabaseService.userId,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(reviewRepositoryProvider).addReviewComment(comment);
      _commentInputController.clear();
      FocusScope.of(context).unfocus();
      ref.invalidate(reviewCommentsProvider(widget.videoId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  Future<void> _updateComment(String commentId, String newText) async {
    try {
      await SupabaseService.instance
          .from('review_comments')
          .update({'comment': newText})
          .eq('id', commentId);
      ref.invalidate(reviewCommentsProvider(widget.videoId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await SupabaseService.instance
          .from('review_comments')
          .delete()
          .eq('id', commentId);
      ref.invalidate(reviewCommentsProvider(widget.videoId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  Future<void> _showEditCommentDialog(ReviewComment comment) async {
    final controller = TextEditingController(text: comment.comment);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Comment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                Navigator.of(ctx).pop();
                await _updateComment(comment.id, newText);
              }
            },
            child: const Text('Save', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _confirmDeleteComment(ReviewComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteComment(comment.id);
    }
  }


  Future<void> _submitFeedback(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Review?'),
        content: const Text('This will lock in your feedback and notify the freelancer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(reviewRepositoryProvider).submitReviewFeedback(review.id);
        ref.invalidate(projectProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review feedback submitted to freelancer!')),
          );
          context.pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    }
  }

  Future<void> _approveReview(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Review?'),
        content: const Text('Approving will mark the project as completed and delete the review video data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 1. Approve the review (sets status + activity log)
        await ref.read(reviewRepositoryProvider).approveReview(review.id);

        // 2. Delete all comments for each video
        final videos = await ref.read(reviewRepositoryProvider).getReviewVideos(review.id);
        for (final video in videos) {
          await SupabaseService.instance
              .from('review_comments')
              .delete()
              .eq('video_id', video.id)
              .timeout(const Duration(seconds: 10));
        }

        // 3. Delete all review videos
        await SupabaseService.instance
            .from('review_videos')
            .delete()
            .eq('review_id', review.id)
            .timeout(const Duration(seconds: 10));

        // 4. Update project status to completed
        await ref.read(projectProvider.notifier).updateStatus(
          widget.projectId,
          ProjectStatus.completed,
        );

        await ref.read(projectProvider.notifier).refresh();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review approved! Project marked as completed.')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve review: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClient = widget.isClient;

    final reviewAsync = ref.watch(latestReviewProvider(widget.projectId));
    final commentsAsync = ref.watch(reviewCommentsProvider(widget.videoId));

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.back,
                size: 18,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: const Text(
          'Video Review Player',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          reviewAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (review) {
              if (review != null && isClient && review.status != 'approved' && review.status != 'completed') {
                final commentsAsync = ref.watch(reviewCommentsProvider(widget.videoId));
                final comments = commentsAsync.valueOrNull ?? [];
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    child: comments.isNotEmpty
                        ? TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 12, color: AppColors.primary),
                            label: const Text(
                              'Submit Feedback',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () => _submitFeedback(review),
                          )
                        : TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              backgroundColor: Colors.green.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.green.withValues(alpha: 0.2)),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                            label: const Text(
                              'Approve',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () => _approveReview(review),
                          ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: AmbientGlowContainer(
        child: reviewAsync.when(
          loading: () => LoadingWidget(message: 'Loading review session...'),
          error: (e, _) => Center(child: Text('Review session error: $e')),
          data: (review) {
            if (review == null) return const Center(child: Text('Review session not found.'));

            return LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final isDesktop = constraints.maxWidth > 800;
                final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0 || _commentFocusNode.hasFocus;

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT SIDE: Video Player & Scrubber
                      Expanded(
                        flex: 6, // 60% width
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.black,
                                child: Center(
                                  child: _isPlayerInitialized && _controller != null
                                      ? AspectRatio(
                                          aspectRatio: _controller!.value.aspectRatio,
                                          child: RepaintBoundary(
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () async {
                                                    if (_controller!.value.isPlaying) {
                                                      await _controller!.pause();
                                                    } else {
                                                      await _controller!.play();
                                                    }
                                                    setState(() {});
                                                  },
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      VideoPlayer(_controller!),
                                                      if (!_controller!.value.isPlaying)
                                                        Container(
                                                          width: 44,
                                                          height: 44,
                                                          decoration: const BoxDecoration(
                                                            color: Colors.black54,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            CupertinoIcons.play_fill,
                                                            size: 22,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                if (_controller!.value.isBuffering)
                                                  Container(
                                                    color: Colors.black38,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : _hasPlayerError
                                          ? _buildPlayerErrorWidget()
                                          : const Center(child: CircularProgressIndicator()),
                                ),
                              ),
                            ),
                            if (_isPlayerInitialized && _controller != null)
                              _buildScrubberWidget(context, isDark),
                          ],
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      ),
                      // RIGHT SIDE: Comments Timeline & Action Footer
                      Expanded(
                        flex: 4, // 40% width
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildCommentsListWidget(isDark, keyboardOpen, commentsAsync),
                            ),
                            _buildActionFooterWidget(isDark, isClient, review),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Mobile Layout
                return Column(
                  children: [
                    // 1. VIDEO PLAYER WINDOW
                    if (_isPlayerInitialized && _controller != null)
                      Column(
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: keyboardOpen
                                  ? availableHeight * 0.25
                                  : availableHeight * 0.35,
                            ),
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: RepaintBoundary(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          if (_controller!.value.isPlaying) {
                                            await _controller!.pause();
                                          } else {
                                            await _controller!.play();
                                          }
                                          setState(() {});
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            VideoPlayer(_controller!),
                                            if (!_controller!.value.isPlaying)
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  CupertinoIcons.play_fill,
                                                  size: 22,
                                                  color: Colors.white,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (_controller!.value.isBuffering)
                                        Container(
                                          color: Colors.black38,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildScrubberWidget(context, isDark),
                        ],
                      )
                    else if (_hasPlayerError)
                      _buildPlayerErrorWidget()
                    else
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),

                    // 2. COMMENTS LIST
                    Expanded(
                      child: _buildCommentsListWidget(isDark, keyboardOpen, commentsAsync),
                    ),

                    // 3. ACTION FOOTER
                    _buildActionFooterWidget(isDark, isClient, review),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerErrorWidget() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.amber),
          const SizedBox(height: 12),
          const Text(
            'Direct playback unsupported',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            'Some cloud settings or private Dropbox links cannot stream directly in-app. Click below to open in your browser, then type comments below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          FutureBuilder<Map<String, dynamic>>(
            future: SupabaseService.instance
                .from('review_videos')
                .select('url')
                .eq('id', widget.videoId)
                .single(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.done && snap.hasData) {
                final videoUrl = snap.data!['url'] as String;
                return ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Video Link'),
                  onPressed: () => _openExternalLink(videoUrl),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScrubberWidget(BuildContext context, bool isDark) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
          thumbColor: AppColors.primary,
        ),
        child: ValueListenableBuilder<Duration>(
          valueListenable: _currentPositionNotifier,
          builder: (context, currentPosition, child) {
            return Slider(
              value: currentPosition.inMilliseconds.toDouble().clamp(
                0.0,
                _totalDuration.inMilliseconds.toDouble(),
              ),
              min: 0.0,
              max: _totalDuration.inMilliseconds.toDouble() > 0
                  ? _totalDuration.inMilliseconds.toDouble()
                  : 100.0,
              onChanged: (value) {
                _isDragging = true;
                _currentPositionNotifier.value = Duration(milliseconds: value.toInt());
              },
              onChangeEnd: (value) async {
                await _seekTo(Duration(milliseconds: value.toInt()));
                _isDragging = false;
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentsListWidget(
    bool isDark,
    bool keyboardOpen,
    AsyncValue<List<ReviewComment>> commentsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!keyboardOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 6.0),
            child: Text(
              'FEEDBACK COMMENTS TIMELINE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
        Expanded(
          child: commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Comments error: $err')),
            data: (comments) {
              if (comments.isEmpty) {
                return keyboardOpen
                    ? const Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      )
                    : const EmptyStateWidget(
                        icon: CupertinoIcons.chat_bubble_2,
                        title: 'No Feedback Comments Yet',
                        subtitle: 'Use the floating action button to leave time-coded comments.',
                      );
              }
              return ListView.builder(
                itemCount: comments.length,
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                itemBuilder: (itemCtx, index) {
                  final comment = comments[index];
                  final authorNameAsync = ref.watch(profileNameProvider(comment.authorId));

                  String timeAgo(DateTime dateTime) {
                    final difference = DateTime.now().difference(dateTime);
                    if (difference.inDays >= 7) {
                      return DateFormat('MMM d').format(dateTime);
                    } else if (difference.inDays >= 1) {
                      return '${difference.inDays}d ago';
                    } else if (difference.inHours >= 1) {
                      return '${difference.inHours}h ago';
                    } else if (difference.inMinutes >= 1) {
                      return '${difference.inMinutes}m ago';
                    } else {
                      return 'Just now';
                    }
                  }

                  final isOwnComment = comment.authorId == SupabaseService.userId;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161A1D) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B3237) : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            final target = Duration(milliseconds: comment.timestampMs);
                            _currentPositionNotifier.value = target;
                            if (_controller != null && _isPlayerInitialized) {
                              _seekTo(target);
                              if (!_controller!.value.isPlaying) {
                                _controller!.play();
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C7A5).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              comment.formattedTimestamp,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00D7B5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Comment and Metadata Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.comment,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              authorNameAsync.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (name) => Text(
                                  '$name • ${timeAgo(comment.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwnComment)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textMuted),
                            padding: EdgeInsets.zero,
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 14),
                                    SizedBox(width: 8),
                                    Text('Edit', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded, size: 14, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showEditCommentDialog(comment);
                              } else if (val == 'delete') {
                                _confirmDeleteComment(comment);
                              }
                            },
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

  Widget _buildActionFooterWidget(bool isDark, bool isClient, Review review) {
    if (isClient && review.status != 'approved' && review.status != 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.card : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Timestamp badge
              ValueListenableBuilder<Duration>(
                valueListenable: _currentPositionNotifier,
                builder: (context, currentPosition, child) {
                  return Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _formatDuration(currentPosition),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // Comment input with integrated send
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentInputController,
                        focusNode: _commentFocusNode,
                        maxLines: 2,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add feedback or comment...',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF131320) : const Color(0xFFF8FAFC),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                        onTap: () {
                          if (_controller?.value.isPlaying ?? false) {
                            _controller!.pause();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        onPressed: () => _addCommentFromInput(review),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (review.status == 'approved' || review.status == 'completed') {
      return Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                review.status == 'approved' ? 'Review Approved' : 'Revisions Completed',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
