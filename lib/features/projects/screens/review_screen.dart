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
import '../widgets/share_link_dialog.dart';
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
  bool _isPlaying = false;
  late final ValueNotifier<Duration> _currentPositionNotifier;
  Duration _totalDuration = Duration.zero;
  Timer? _positionTimer;
  bool _isDragging = false;
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToCommentId;
  final TextEditingController _replyInputController = TextEditingController();

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
      // Sync play/pause state so UI icons update (critical for web)
      final playing = _controller!.value.isPlaying;
      if (playing != _isPlaying) {
        setState(() {
          _isPlaying = playing;
        });
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
    _replyInputController.dispose();
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
      try {
        await _controller!.seekTo(position);
        await Future.delayed(const Duration(milliseconds: 50));
        if (wasPlaying && !_controller!.value.isPlaying) {
          await _controller!.play();
        }
      } catch (e) {
        debugPrint('[ReviewScreen] _seekTo failed: $e');
      }
      if (mounted) {
        _currentPositionNotifier.value = position;
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_controller == null || !_isPlayerInitialized) return;
    try {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      if (mounted) {
        setState(() {
          _isPlaying = _controller!.value.isPlaying;
        });
      }
    } catch (e) {
      debugPrint('[ReviewScreen] _togglePlay failed: $e');
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

      // If I'm the client, notify the freelancer
      if (widget.isClient) {
        unawaited(() async {
          try {
            final projRes = await SupabaseService.instance
                .from('projects')
                .select('name, user_id')
                .eq('id', widget.projectId)
                .single()
                .timeout(const Duration(seconds: 10));
            final freelancerUserId = projRes['user_id'] as String;
            final projectName = projRes['name'] as String? ?? 'Project';
            final truncated = text.length > 50 ? '${text.substring(0, 50)}...' : text;
            await SupabaseService.instance.functions.invoke(
              'send-push',
              body: {
                'recipientUserId': freelancerUserId,
                'title': '💬 Review Comment on $projectName',
                'body': 'Client: "$truncated"',
                'route': '/projects/${widget.projectId}',
              },
            );
          } catch (e) {
            debugPrint('[REVIEW PUSH ERROR] $e');
          }
        }());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  Future<void> _addReply(String parentId, int timestampMs) async {
    final text = _replyInputController.text.trim();
    if (text.isEmpty) return;

    final comment = ReviewComment(
      id: '',
      videoId: widget.videoId,
      timestampMs: timestampMs,
      comment: text,
      authorId: SupabaseService.userId,
      createdAt: DateTime.now(),
      parentId: parentId,
    );

    try {
      await ref.read(reviewRepositoryProvider).addReviewComment(comment);
      setState(() {
        _replyingToCommentId = null;
        _replyInputController.clear();
      });
      ref.invalidate(reviewCommentsProvider(widget.videoId));

      // If I'm the client, notify the freelancer
      if (widget.isClient) {
        unawaited(() async {
          try {
            final projRes = await SupabaseService.instance
                .from('projects')
                .select('name, user_id')
                .eq('id', widget.projectId)
                .single()
                .timeout(const Duration(seconds: 10));
            final freelancerUserId = projRes['user_id'] as String;
            final projectName = projRes['name'] as String? ?? 'Project';
            final truncated = text.length > 50 ? '${text.substring(0, 50)}...' : text;
            await SupabaseService.instance.functions.invoke(
              'send-push',
              body: {
                'recipientUserId': freelancerUserId,
                'title': '💬 Review Reply on $projectName',
                'body': 'Client: "$truncated"',
                'route': '/projects/${widget.projectId}',
              },
            );
          } catch (e) {
            debugPrint('[REVIEW PUSH ERROR] $e');
          }
        }());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add reply: $e')),
        );
      }
    }
  }

  Future<void> _toggleReaction(ReviewComment comment, String emoji) async {
    final myId = SupabaseService.userId ?? 'User';
    final reactions = Map<String, dynamic>.from(comment.reactions);
    final list = List<String>.from(reactions[emoji] as List? ?? []);

    if (list.contains(myId)) {
      list.remove(myId);
    } else {
      list.add(myId);
    }

    if (list.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = list;
    }

    try {
      await ref.read(reviewRepositoryProvider).updateReviewCommentReactions(comment.id, reactions);
      ref.invalidate(reviewCommentsProvider(widget.videoId));
    } catch (e) {
      debugPrint('[REACTION ERROR] $e');
    }
  }

  Future<void> _cycleTaskStatus(ReviewComment comment) async {
    String nextStatus;
    if (comment.taskStatus == 'pending') {
      nextStatus = 'in_progress';
    } else if (comment.taskStatus == 'in_progress') {
      nextStatus = 'resolved';
    } else {
      nextStatus = 'pending';
    }

    try {
      await ref.read(reviewRepositoryProvider).updateReviewCommentTaskStatus(comment.id, nextStatus);
      ref.invalidate(reviewCommentsProvider(widget.videoId));
    } catch (e) {
      debugPrint('[STATUS CYCLE ERROR] $e');
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
    try {
      final videos = await ref.read(reviewRepositoryProvider).getReviewVideos(review.id);
      final currentVideo = videos.firstWhere((v) => v.id == widget.videoId, orElse: () => videos.first);
      
      // Calculate active pending videos (exclude already approved ones)
      final pendingVideos = videos.where((v) => !v.isApproved).toList();
      final isLastPending = pendingVideos.length <= 1 && pendingVideos.any((v) => v.id == widget.videoId);

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(!isLastPending ? 'Approve Video?' : 'Approve Review?'),
          content: Text(!isLastPending
              ? 'Are you sure you want to approve "${currentVideo.name}"? This video will be marked as approved.'
              : 'Approving will mark the review session and project as completed.'),
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
        // Prefix the approved video name with [Approved] if not already present
        final newName = currentVideo.name.startsWith('[Approved] ')
            ? currentVideo.name
            : '[Approved] ${currentVideo.name}';
            
        await SupabaseService.instance
            .from('review_videos')
            .update({'name': newName})
            .eq('id', widget.videoId)
            .timeout(const Duration(seconds: 10));

        if (!isLastPending) {
          // Log activity for the freelancer for specific video approval
          try {
            final projectRes = await SupabaseService.instance
                .from('projects')
                .select('name, user_id')
                .eq('id', widget.projectId)
                .single()
                .timeout(const Duration(seconds: 10));

            final freelancerUserId = projectRes['user_id'] as String;
            final projectName = projectRes['name'] as String;

            await SupabaseService.instance.from('activities').insert({
              'user_id': freelancerUserId,
              'type': 'video_approved',
              'description': 'Client approved video "${currentVideo.name}" for "$projectName"',
              'reference_id': widget.projectId,
              'reference_type': 'project',
              'created_at': DateTime.now().toIso8601String(),
            }).timeout(const Duration(seconds: 10));
          } catch (e) {
            debugPrint('Failed to log video approval activity: $e');
          }

          ref.invalidate(latestReviewProvider(widget.projectId));
          await ref.read(projectProvider.notifier).refresh();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Video "${currentVideo.name}" approved!')),
            );
            context.pop();
          }
        } else {
          // 1. Approve the review (sets status + activity log)
          await ref.read(reviewRepositoryProvider).approveReview(review.id);

          // 2. Update project status to completed
          await ref.read(projectProvider.notifier).updateStatus(
            widget.projectId,
            ProjectStatus.completed,
          );

          ref.invalidate(latestReviewProvider(widget.projectId));
          await ref.read(projectProvider.notifier).refresh();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Review approved! Project marked as completed.')),
            );
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve review: $e')),
        );
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
              if (review == null) return const SizedBox.shrink();
              
              final isApproved = review.status == 'approved' || review.status == 'completed';
              
              Widget actionWidget = const SizedBox.shrink();
              
              if (isApproved) {
                actionWidget = Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Approved',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                final videosAsync = ref.watch(reviewVideosProvider(review.id));
                actionWidget = videosAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (videos) {
                    final currentVideo = videos.firstWhere((v) => v.id == widget.videoId, orElse: () => videos.first);
                    if (currentVideo.isApproved) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Approved',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    
                    if (!isClient) return const SizedBox.shrink();
                    
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
                  },
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.share, size: 20),
                    tooltip: 'Share Review Link',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ShareLinkDialog(reviewId: review.id),
                      );
                    },
                  ),
                  actionWidget,
                ],
              );
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
                                                VideoPlayer(_controller!),
                                                // Transparent overlay to capture taps (works on web where platform views swallow gestures)
                                                Positioned.fill(
                                                  child: GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: _togglePlay,
                                                    child: Container(color: Colors.transparent),
                                                  ),
                                                ),
                                                if (!_isPlaying)
                                                  IgnorePointer(
                                                    child: Container(
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
                                                  ),
                                                if (_controller!.value.isBuffering)
                                                  IgnorePointer(
                                                    child: Container(
                                                      color: Colors.black38,
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                                        ),
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
                                      VideoPlayer(_controller!),
                                      // Transparent overlay to capture taps (works on web where platform views swallow gestures)
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: _togglePlay,
                                          child: Container(color: Colors.transparent),
                                        ),
                                      ),
                                      if (!_isPlaying)
                                        IgnorePointer(
                                          child: Container(
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
                                        ),
                                      if (_controller!.value.isBuffering)
                                        IgnorePointer(
                                          child: Container(
                                            color: Colors.black38,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          // Play/Pause button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 8),
          // Timeline Slider
          Expanded(
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
          ),
          const SizedBox(width: 8),
          // Position label / Total duration
          ValueListenableBuilder<Duration>(
            valueListenable: _currentPositionNotifier,
            builder: (context, currentPosition, child) {
              final currentStr = _formatDuration(currentPosition);
              final totalStr = _formatDuration(_totalDuration);
              return Text(
                '$currentStr / $totalStr',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
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
              final parentComments = comments.where((c) => c.parentId == null).toList();
              parentComments.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

              return ListView.builder(
                itemCount: parentComments.length,
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                itemBuilder: (itemCtx, index) {
                  final parent = parentComments[index];
                  final replies = comments.where((c) => c.parentId == parent.id).toList();
                  replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                  final isDark = Theme.of(context).brightness == Brightness.dark;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCommentCard(parent, false, comments),
                      if (_replyingToCommentId == parent.id)
                        Padding(
                          padding: const EdgeInsets.only(left: 34.0, right: 6.0, top: 4.0, bottom: 4.0),
                          child: _buildReplyInputBox(parent, isDark),
                        ),
                      if (replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: replies.map((reply) => _buildCommentCard(reply, true, comments)).toList(),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReactions(ReviewComment comment) {
    final myId = SupabaseService.userId ?? 'User';
    final emojis = ['👍', '❤️', '😮', '✏️', '🚀'];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...emojis.map((emoji) {
          final list = List<String>.from(comment.reactions[emoji] as List? ?? []);
          final reacted = list.contains(myId);
          if (list.isEmpty) {
            return InkWell(
              onTap: () => _toggleReaction(comment, emoji),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(emoji, style: const TextStyle(fontSize: 12)),
              ),
            );
          }
          return InkWell(
            onTap: () => _toggleReaction(comment, emoji),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: reacted
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: reacted
                      ? AppColors.primaryNeon.withValues(alpha: 0.5)
                      : AppColors.border,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '${list.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: reacted ? AppColors.primaryNeon : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAvatar(String name, bool isDark) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
    ];
    final colorIndex = name.hashCode.abs() % colors.length;
    final bgColor = colors[colorIndex];

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReplyInputBox(ReviewComment parent, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 2.0, bottom: 6.0),
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A1D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF22262B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: AppColors.primaryNeon),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _replyInputController,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Reply to this thread...',
                hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _replyingToCommentId = null;
              });
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 16, color: AppColors.primaryNeon),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _addReply(parent.id, parent.timestampMs),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildCommentCard(ReviewComment comment, bool isReply, List<ReviewComment> allComments) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authorNameAsync = ref.watch(profileNameProvider(comment.authorId));
    final isOwnComment = comment.authorId == SupabaseService.userId;

    String formatExactTime(DateTime dateTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime.toLocal());
    }

    final authorName = authorNameAsync.value ?? 'User';

    return Opacity(
      opacity: comment.isResolved ? 0.65 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13171B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: comment.isResolved
                ? AppColors.success.withValues(alpha: 0.2)
                : (isDark ? const Color(0xFF22262B) : const Color(0xFFE2E8F0)),
            width: 0.8,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(authorName, isDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isReply)
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
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C7A5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              comment.formattedTimestamp,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00D7B5),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (!isReply) ...[
                        IconButton(
                          icon: Icon(
                            comment.taskStatus == 'resolved'
                                ? Icons.check_circle_rounded
                                : (comment.taskStatus == 'in_progress'
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.radio_button_unchecked_rounded),
                            color: comment.taskStatus == 'resolved'
                                ? AppColors.success
                                : (comment.taskStatus == 'in_progress'
                                    ? Colors.orange
                                    : AppColors.textMuted),
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.isClient ? null : () => _cycleTaskStatus(comment),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (isOwnComment)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 14, color: AppColors.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 13),
                                  SizedBox(width: 8),
                                  Text('Edit', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_rounded, size: 13, color: Colors.red),
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
                  const SizedBox(height: 6),
                  Text(
                    comment.comment,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      decoration: comment.isResolved ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatExactTime(comment.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                        ),
                      ),
                      if (!isReply)
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_replyingToCommentId == comment.id) {
                                _replyingToCommentId = null;
                              } else {
                                _replyingToCommentId = comment.id;
                                _replyInputController.clear();
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply_rounded, size: 12, color: AppColors.primaryNeon),
                                SizedBox(width: 2),
                                Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryNeon,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFooterWidget(bool isDark, bool isClient, Review review) {
    final isReviewApproved = review.status == 'approved' || review.status == 'completed';
    
    final videosAsync = ref.watch(reviewVideosProvider(review.id));
    final currentVideoApproved = videosAsync.when(
      data: (videos) {
        if (videos.isEmpty) return false;
        final currentVideo = videos.firstWhere((v) => v.id == widget.videoId, orElse: () => videos.first);
        return currentVideo.isApproved;
      },
      loading: () => false,
      error: (_, __) => false,
    );

    if (isReviewApproved || currentVideoApproved) {
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
                isReviewApproved && review.status == 'completed' ? 'Revisions Completed' : 'Review Approved',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ),
      );
    }

    if (isClient) {
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
    }
    return const SizedBox.shrink();
  }
}
