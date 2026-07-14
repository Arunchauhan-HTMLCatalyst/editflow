import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/review_repository.dart';
import '../models/review.dart';
import '../models/review_video.dart';
import '../models/review_comment.dart';
import '../../../services/supabase_service.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

final latestReviewProvider = StreamProvider.family<Review?, String>((ref, projectId) {
  return SupabaseService.instance
      .from('reviews')
      .stream(primaryKey: ['id'])
      .eq('project_id', projectId)
      .map((list) {
        if (list.isEmpty) return null;
        final sorted = List<Map<String, dynamic>>.from(list);
        sorted.sort((a, b) => DateTime.parse(b['created_at'] as String)
            .compareTo(DateTime.parse(a['created_at'] as String)));
        return Review.fromJson(sorted.first);
      });
});

final reviewVideosProvider = StreamProvider.family<List<ReviewVideo>, String>((ref, reviewId) {
  return SupabaseService.instance
      .from('review_videos')
      .stream(primaryKey: ['id'])
      .eq('review_id', reviewId)
      .map((list) {
        // Deduplicate to prevent realtime stream duplication bugs
        final seenIds = <String>{};
        final uniqueList = <Map<String, dynamic>>[];
        for (final item in list) {
          final id = item['id'] as String?;
          if (id != null && !seenIds.contains(id)) {
            seenIds.add(id);
            uniqueList.add(item);
          }
        }
        final sorted = List<Map<String, dynamic>>.from(uniqueList);
        sorted.sort((a, b) => DateTime.parse(a['created_at'] as String)
            .compareTo(DateTime.parse(b['created_at'] as String)));
        return sorted.map((e) => ReviewVideo.fromJson(e)).toList();
      });
});

final reviewCommentsProvider = StreamProvider.family<List<ReviewComment>, String>((ref, videoId) {
  return SupabaseService.instance
      .from('review_comments')
      .stream(primaryKey: ['id'])
      .eq('video_id', videoId)
      .map((list) {
        // Deduplicate to prevent realtime stream duplication bugs
        final seenIds = <String>{};
        final uniqueList = <Map<String, dynamic>>[];
        for (final item in list) {
          final id = item['id'] as String?;
          if (id != null && !seenIds.contains(id)) {
            seenIds.add(id);
            uniqueList.add(item);
          }
        }
        final sorted = List<Map<String, dynamic>>.from(uniqueList);
        sorted.sort((a, b) => (a['timestamp_ms'] as num)
            .compareTo(b['timestamp_ms'] as num));
        return sorted.map((e) => ReviewComment.fromJson(e)).toList();
      });
});

/// Reactive profile lookup provider that fetches the display name of any user
final profileNameProvider = FutureProvider.family<String, String>((ref, userId) async {
  try {
    final response = await SupabaseService.instance
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (response != null && response['full_name'] != null) {
      return response['full_name'] as String;
    }
  } catch (_) {}
  return 'User';
});

typedef PublicCommentsArg = ({String token, String videoId});

final publicReviewCommentsProvider = StreamProvider.family<List<ReviewComment>, PublicCommentsArg>((ref, arg) {
  final controller = StreamController<List<ReviewComment>>();
  Timer? timer;

  Future<void> fetch() async {
    try {
      final repo = ref.read(reviewRepositoryProvider);
      final comments = await repo.getReviewCommentsByShareToken(arg.token, arg.videoId);
      if (!controller.isClosed) {
        controller.add(comments);
      }
    } catch (_) {}
  }

  fetch();
  timer = Timer.periodic(const Duration(seconds: 4), (_) => fetch());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

final projectReviewCommentsCountProvider = Provider.family<int, String>((ref, projectId) {
  final review = ref.watch(latestReviewProvider(projectId)).valueOrNull;
  if (review == null) return 0;

  final videos = ref.watch(reviewVideosProvider(review.id)).valueOrNull ?? [];
  if (videos.isEmpty) return 0;

  int total = 0;
  for (final video in videos) {
    final comments = ref.watch(reviewCommentsProvider(video.id)).valueOrNull ?? [];
    total += comments.length;
  }
  return total;
});

