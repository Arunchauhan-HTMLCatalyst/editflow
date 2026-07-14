import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/video_source_provider.dart';
import '../models/review.dart';
import '../models/review_video.dart';
import '../models/review_comment.dart';
import '../models/review_share.dart';
import '../providers/review_provider.dart';

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

  VideoPlayerController? _controller;
  bool _isPlayerInitialized = false;
  bool _hasPlayerError = false;
  bool _isPlaying = false;
  late final ValueNotifier<Duration> _currentPositionNotifier;
  Duration _totalDuration = Duration.zero;
  bool _isDragging = false;

  final TextEditingController _nameInputController = TextEditingController();
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentPositionNotifier = ValueNotifier<Duration>(Duration.zero);
    _loadInitialData();
  }

  @override
  void dispose() {
    _currentPositionNotifier.dispose();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _nameInputController.dispose();
    _commentInputController.dispose();
    _commentFocusNode.dispose();
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
          _errorMessage = share == null
              ? 'This share link is invalid.'
              : 'This share link has expired.';
          _isLoading = false;
        });
        return;
      }
      _shareInfo = share;

      // 2. Fetch Review details
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
      await _controller!.dispose();
      _controller = null;
      setState(() {
        _isPlayerInitialized = false;
        _hasPlayerError = false;
      });
    }

    try {
      final playableUrl = VideoSourceManager.getPlayableUrl(_currentVideo!.url);
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
      debugPrint('[PublicReviewScreen] Video player init failed: $e');
      if (mounted) {
        setState(() {
          _hasPlayerError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    if (_controller!.value.isInitialized) {
      if (!_isDragging) {
        _currentPositionNotifier.value = _controller!.value.position;
      }
      final playing = _controller!.value.isPlaying;
      if (playing != _isPlaying) {
        setState(() {
          _isPlaying = playing;
        });
      }
    }
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
        debugPrint('[PublicReviewScreen] _seekTo failed: $e');
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
      debugPrint('[PublicReviewScreen] _togglePlay failed: $e');
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
      await repo.addReviewCommentByShareToken(widget.shareToken, comment);
      _commentInputController.clear();
      _commentFocusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AmbientGlowContainer(
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AmbientGlowContainer(
                  child: Card(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
                              size: 40, color: AppColors.primary),
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
              ],
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared Review Player',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(
              'Logged in as: $_guestName (Guest)',
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
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
      body: SafeArea(
        child: Column(
          children: [
            // 1. Video Player Component
            _buildVideoPlayerSection(isDark),
            
            // 2. Video switcher if multiple videos
            if (_videos.length > 1) _buildVideoSwitcher(isDark),

            // 3. Comments section
            Expanded(
              child: _buildCommentsSection(isDark),
            ),

            // 4. Input bar
            _buildCommentInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerSection(bool isDark) {
    if (_hasPlayerError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black87,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              SizedBox(height: 8),
              Text('Failed to load video review stream', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (!_isPlayerInitialized || _controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black87,
          child: const Center(child: CupertinoActivityIndicator(color: Colors.white)),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                // Overlay play controls on tap
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlay,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Play Center Icon
                if (!_isPlaying)
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                    onPressed: _togglePlay,
                  ),
              ],
            ),
          ),
        ),
        // Play controls and timeline slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 8),
              // Timeline Slider
              Expanded(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: _currentPositionNotifier,
                  builder: (context, position, child) {
                    final double maxMs = _totalDuration.inMilliseconds.toDouble();
                    final double currentMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);
                    
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                        thumbColor: AppColors.primary,
                      ),
                      child: Slider(
                        value: currentMs,
                        min: 0,
                        max: maxMs > 0 ? maxMs : 1.0,
                        onChangeStart: (val) {
                          _isDragging = true;
                        },
                        onChanged: (val) {
                          _currentPositionNotifier.value = Duration(milliseconds: val.toInt());
                        },
                        onChangeEnd: (val) async {
                          _isDragging = false;
                          await _seekTo(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Time Labels
              ValueListenableBuilder<Duration>(
                valueListenable: _currentPositionNotifier,
                builder: (context, position, child) {
                  return Text(
                    '${_formatDuration(position)} / ${_formatDuration(_totalDuration)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                  );
                },
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildCommentsSection(bool isDark) {
    if (_currentVideo == null) return const SizedBox.shrink();

    final commentsAsync = ref.watch(publicReviewCommentsProvider((
      token: widget.shareToken,
      videoId: _currentVideo!.id,
    )));

    return commentsAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, __) => Center(child: Text('Failed to load feedback comments: $e')),
      data: (comments) {
        if (comments.isEmpty) {
          return const Center(
            child: EmptyStateWidget(
              icon: CupertinoIcons.chat_bubble_2,
              title: 'No Feedback Yet',
              subtitle: 'Play the video and write a comment to leave feedback.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            final duration = Duration(milliseconds: comment.timestampMs);
            
            // Try to split Guest indicator
            final parts = comment.comment.split(' (Guest): ');
            final isGuest = parts.length > 1;
            final authorName = isGuest ? parts[0] : 'Freelancer';
            final commentBody = isGuest ? parts[1] : comment.comment;

            return ListTile(
              dense: true,
              leading: GestureDetector(
                onTap: () => _seekTo(duration),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (isGuest) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('GUEST', style: TextStyle(fontSize: 8, color: Colors.grey)),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                commentBody,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
              ),
              trailing: Text(
                DateFormat('hh:mm a').format(comment.createdAt.toLocal()),
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentInputController,
              focusNode: _commentFocusNode,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Add comment at ${_formatDuration(_currentPositionNotifier.value)}...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
            onPressed: _submitComment,
          ),
        ],
      ),
    );
  }
}
