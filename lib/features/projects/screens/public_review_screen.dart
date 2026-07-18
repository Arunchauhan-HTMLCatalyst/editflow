import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ef_logo.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/video_source_provider.dart';
import '../models/review_video.dart';
import '../models/review_comment.dart';
import '../models/review_share.dart';
import '../providers/review_provider.dart';
import '../../../services/supabase_service.dart';

class PublicReviewScreen extends ConsumerStatefulWidget {
  final String shareToken;

  const PublicReviewScreen({
    super.key,
    required this.shareToken,
  });

  @override
  ConsumerState<PublicReviewScreen> createState() => _PublicReviewScreenState();
}

class _PublicReviewScreenState extends ConsumerState<PublicReviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  ReviewShare? _shareInfo;
  List<ReviewVideo> _videos = [];
  ReviewVideo? _currentVideo;
  String? _guestName;
  List<String> _myGuestCommentIds = [];

  VideoPlayerController? _controller;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _hasPlayerError = false;
  Duration _totalDuration = Duration.zero;

  final ValueNotifier<Duration> _currentPositionNotifier = ValueNotifier<Duration>(Duration.zero);
  bool _isDragging = false;

  final TextEditingController _nameInputController = TextEditingController();
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToCommentId;
  final TextEditingController _replyInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
    }
    _currentPositionNotifier.dispose();
    _nameInputController.dispose();
    _commentInputController.dispose();
    _commentFocusNode.dispose();
    _replyInputController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(reviewRepositoryProvider);
      
      // 1. Fetch Share Info
      final share = await repo.getReviewShare(widget.shareToken);
      if (share == null || share.isExpired) {
        setState(() {
          _errorMessage = 'This share link has expired.';
          _isLoading = false;
        });
        return;
      }
      _shareInfo = share;

      // 2. Fetch Review details to verify existence
      final review = await repo.getReviewByShareToken(widget.shareToken, share.reviewId);
      if (review == null) {
        setState(() {
          _errorMessage = 'The associated review records could not be retrieved.';
          _isLoading = false;
        });
        return;
      }

      // 3. Fetch Videos
      final videos = await repo.getReviewVideosByShareToken(widget.shareToken, share.reviewId);
      if (videos.isEmpty) {
        setState(() {
          _errorMessage = 'No review videos found for this project.';
          _isLoading = false;
        });
        return;
      }
      _videos = videos;
      _currentVideo = videos.first;

      // 4. Check Guest Name
      final prefs = await SharedPreferences.getInstance();
      _guestName = prefs.getString('guest_name');
      _myGuestCommentIds = prefs.getStringList('my_guest_comment_ids_${widget.shareToken}') ?? [];

      // 5. Initialize Video Player
      if (_guestName != null && _guestName!.isNotEmpty) {
        await _initializeVideoPlayer();
      }
    } catch (e) {
      debugPrint('[PublicReviewScreen._loadInitialData] Error: $e');
      setState(() {
        _errorMessage = 'An error occurred while loading this review page.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_currentVideo == null) return;

    // Clean up old controller if any
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
      _isPlayerInitialized = false;
    }

    try {
      final url = _currentVideo!.url;
      final playableUrl = VideoSourceManager.getPlayableUrl(url);
      
      final Uri uri = Uri.parse(playableUrl);
      _controller = VideoPlayerController.networkUrl(uri);
      
      await _controller!.initialize();
      _controller!.addListener(_videoListener);
      _totalDuration = _controller!.value.duration;
      _isPlayerInitialized = true;
      _hasPlayerError = false;
    } catch (e) {
      debugPrint('[PublicReviewScreen] Video player init failed: $e');
      _isPlayerInitialized = false;
      _hasPlayerError = true;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _videoListener() {
    if (_controller != null && !_isDragging) {
      _currentPositionNotifier.value = _controller!.value.position;
      final playing = _controller!.value.isPlaying;
      if (playing != _isPlaying) {
        setState(() {
          _isPlaying = playing;
        });
      }
    }
  }

  Future<void> _seekTo(Duration duration) async {
    if (_controller != null && _isPlayerInitialized) {
      try {
        await _controller!.seekTo(duration);
        _currentPositionNotifier.value = duration;
      } catch (e) {
        debugPrint('[PublicReviewScreen] _seekTo failed: $e');
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_controller != null && _isPlayerInitialized) {
      try {
        if (_isPlaying) {
          await _controller!.pause();
        } else {
          await _controller!.play();
        }
      } catch (e) {
        debugPrint('[PublicReviewScreen] _togglePlay failed: $e');
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _submitGuestName() async {
    final name = _nameInputController.text.trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_name', name);

    setState(() {
      _guestName = name;
      _isLoading = true;
    });

    await _initializeVideoPlayer();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentInputController.text.trim();
    if (text.isEmpty || _currentVideo == null || _shareInfo == null || _guestName == null) return;

    final currentMs = _currentPositionNotifier.value.inMilliseconds;
    final guestFormattedComment = '$_guestName (Guest): $text';

    final comment = ReviewComment(
      id: '',
      videoId: _currentVideo!.id,
      timestampMs: currentMs,
      comment: guestFormattedComment,
      authorId: _shareInfo!.createdBy, // Fallback to link creator's ID to satisfy DB constraints
      createdAt: DateTime.now(),
    );

    try {
      final repo = ref.read(reviewRepositoryProvider);
      final newComment = await repo.addReviewCommentByShareToken(widget.shareToken, comment);
      
      final prefs = await SharedPreferences.getInstance();
      _myGuestCommentIds.add(newComment.id);
      await prefs.setStringList('my_guest_comment_ids_${widget.shareToken}', _myGuestCommentIds);
      
      setState(() {});
      _commentInputController.clear();
      _commentFocusNode.unfocus();

      // Fire-and-forget push notification to the freelancer
      unawaited(() async {
        try {
          final freelancerUserId = _shareInfo!.createdBy;
          final truncated = text.length > 50 ? '${text.substring(0, 50)}...' : text;
          await SupabaseService.instance.functions.invoke(
            'send-push',
            body: {
              'recipientUserId': freelancerUserId,
              'title': '💬 New Review Comment',
              'body': '$_guestName (Guest): "$truncated"',
              'route': '/dashboard',
            },
          );
        } catch (e) {
          debugPrint('[REVIEW PUSH ERROR] $e');
        }
      }());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Future<void> _addReply(String parentId, int timestampMs) async {
    final text = _replyInputController.text.trim();
    if (text.isEmpty || _currentVideo == null || _shareInfo == null || _guestName == null) return;

    final guestFormattedComment = '$_guestName (Guest): $text';

    final comment = ReviewComment(
      id: '',
      videoId: _currentVideo!.id,
      timestampMs: timestampMs,
      comment: guestFormattedComment,
      authorId: _shareInfo!.createdBy,
      createdAt: DateTime.now(),
      parentId: parentId,
    );

    try {
      final repo = ref.read(reviewRepositoryProvider);
      final newComment = await repo.addReviewCommentByShareToken(widget.shareToken, comment);
      
      final prefs = await SharedPreferences.getInstance();
      _myGuestCommentIds.add(newComment.id);
      await prefs.setStringList('my_guest_comment_ids_${widget.shareToken}', _myGuestCommentIds);

      setState(() {
        _replyingToCommentId = null;
        _replyInputController.clear();
      });

      // Fire-and-forget push notification to the freelancer
      unawaited(() async {
        try {
          final freelancerUserId = _shareInfo!.createdBy;
          final truncated = text.length > 50 ? '${text.substring(0, 50)}...' : text;
          await SupabaseService.instance.functions.invoke(
            'send-push',
            body: {
              'recipientUserId': freelancerUserId,
              'title': '💬 Review Reply',
              'body': '$_guestName (Guest): "$truncated"',
              'route': '/dashboard',
            },
          );
        } catch (e) {
          debugPrint('[REVIEW PUSH ERROR] $e');
        }
      }());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add reply: $e')),
        );
      }
    }
  }

  Future<void> _toggleReaction(ReviewComment comment, String emoji) async {
    final myId = _guestName ?? 'Guest';
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
      await ref.read(reviewRepositoryProvider).updateReviewCommentReactionsByShareToken(
        widget.shareToken,
        comment.id,
        reactions,
      );
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
      await ref.read(reviewRepositoryProvider).updateReviewCommentTaskStatusByShareToken(
        widget.shareToken,
        comment.id,
        nextStatus,
      );
    } catch (e) {
      debugPrint('[STATUS CYCLE ERROR] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
        body: const Center(child: LoadingWidget()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
        body: AmbientGlowContainer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.lock_shield, size: 48, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Review Access Restricted',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_guestName == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
        body: AmbientGlowContainer(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EfLogo(size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Join Project Review',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your name to view the video and post feedback.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameInputController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Your Display Name',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _submitGuestName(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _submitGuestName,
                            child: const Text('Start Review', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : CupertinoColors.systemBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const EfLogo(size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EditFlow Review',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  'Guest: $_guestName',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.square_arrow_right),
            tooltip: 'Change Name',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('guest_name');
              setState(() {
                _guestName = null;
              });
            },
          ),
        ],
      ),
      body: AmbientGlowContainer(
        child: LayoutBuilder(
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
                                      : const Center(child: CupertinoActivityIndicator(color: Colors.white)),
                            ),
                          ),
                        ),
                        if (_isPlayerInitialized && _controller != null)
                          _buildScrubberWidget(context, isDark),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  Container(
                    width: 1,
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                  ),
                  // RIGHT SIDE: Revisions Switcher, Comments Timeline, Comment Input
                  Expanded(
                    flex: 4, // 40% width
                    child: Column(
                      children: [
                        if (_videos.length > 1) _buildVideoSwitcher(isDark),
                        Expanded(
                          child: _buildCommentsSection(isDark, keyboardOpen),
                        ),
                        _buildCommentInputBar(isDark),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Mobile Layout
            return Column(
              children: [
                // 1. Video window
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
                    child: CupertinoActivityIndicator(),
                  ),

                // 2. Video Switcher (Revisions)
                if (_videos.length > 1) _buildVideoSwitcher(isDark),

                // 3. Comments list
                Expanded(
                  child: _buildCommentsSection(isDark, keyboardOpen),
                ),

                // 4. Action input bar
                _buildCommentInputBar(isDark),
              ],
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
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: Colors.amber),
          SizedBox(height: 12),
          Text(
            'Direct playback unsupported',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'This cloud link cannot stream directly. Open the review link directly, or type comments sync-linked below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 8),
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
                builder: (context, position, child) {
                  return Slider(
                    value: position.inMilliseconds.toDouble().clamp(
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
          ValueListenableBuilder<Duration>(
            valueListenable: _currentPositionNotifier,
            builder: (context, position, child) {
              return Text(
                '${_formatDuration(position)} / ${_formatDuration(_totalDuration)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(ReviewComment comment) {
    final myId = _guestName ?? 'Guest';
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
    final isMyComment = _myGuestCommentIds.contains(comment.id);

    final parts = comment.comment.split(' (Guest): ');
    final isGuest = parts.length > 1;
    final authorName = isGuest ? parts[0] : 'Freelancer';
    final commentBody = isGuest ? parts[1] : comment.comment;

    String formatExactTime(DateTime dateTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime.toLocal());
    }

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
                      if (isGuest) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'GUEST',
                            style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      if (!isReply)
                        InkWell(
                          onTap: () => _seekTo(Duration(milliseconds: comment.timestampMs)),
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
                          onPressed: null, // Guests cannot modify task status
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (isMyComment)
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
                              _editComment(comment);
                            } else if (val == 'delete') {
                              _confirmDeleteComment(comment);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    commentBody,
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

  Widget _buildVideoSwitcher(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          const Text('Revisions: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _videos.length,
              separatorBuilder: (context, idx) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final video = _videos[index];
                final isSelected = video.id == _currentVideo?.id;
                return ChoiceChip(
                  label: Text(
                    video.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundColor: Colors.transparent,
                  checkmarkColor: AppColors.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentVideo = video;
                        _isLoading = true;
                      });
                      _initializeVideoPlayer().then((_) {
                        if (mounted) setState(() => _isLoading = false);
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(bool isDark, bool keyboardOpen) {
    if (_currentVideo == null) return const SizedBox.shrink();

    final commentsAsync = ref.watch(publicReviewCommentsProvider((
      token: widget.shareToken,
      videoId: _currentVideo!.id,
    )));

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
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, __) => Center(child: Text('Failed to load feedback comments: $e')),
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
                        subtitle: 'Play the video and write a comment to leave feedback.',
                      );
              }

              final parentComments = comments.where((c) => c.parentId == null).toList();
              parentComments.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                itemCount: parentComments.length,
                itemBuilder: (context, index) {
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
        if (!keyboardOpen)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2B3237) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EfLogo(size: 14),
                const SizedBox(width: 6),
                Text(
                  'Powered by EditFlow',
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.w600, 
                    color: isDark ? Colors.white38 : Colors.black38
                  ),
                ),
                Text(
                  ' | editflow.acsoft.online',
                  style: TextStyle(
                    fontSize: 10, 
                    color: isDark ? AppColors.primary.withOpacity(0.5) : AppColors.primary.withOpacity(0.7)
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editComment(ReviewComment comment) async {
    final TextEditingController editController = TextEditingController(
      text: comment.comment.split(' (Guest): ').length > 1 
          ? comment.comment.split(' (Guest): ')[1] 
          : comment.comment
    );

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111625) : Colors.white,
          title: const Text('Edit Comment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: editController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter new comment text...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isEmpty) return;
                Navigator.pop(context);

                final guestFormattedComment = '$_guestName (Guest): $newText';
                try {
                  final repo = ref.read(reviewRepositoryProvider);
                  await repo.updateReviewCommentByShareToken(
                    widget.shareToken,
                    comment.id,
                    guestFormattedComment,
                  );
                  ref.invalidate(publicReviewCommentsProvider);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update comment: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteComment(ReviewComment comment) async {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111625) : Colors.white,
          title: const Text('Delete Comment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final repo = ref.read(reviewRepositoryProvider);
                  await repo.deleteReviewCommentByShareToken(widget.shareToken, comment.id);
                  
                  _myGuestCommentIds.remove(comment.id);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('my_guest_comment_ids_${widget.shareToken}', _myGuestCommentIds);
                  
                  ref.invalidate(publicReviewCommentsProvider);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete comment: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentInputBar(bool isDark) {
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
                      onPressed: _submitComment,
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
}
