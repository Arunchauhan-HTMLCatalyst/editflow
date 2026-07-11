import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';

/// A [FutureProvider] that fetches comments once for a given project.
/// Invalidate or refresh this provider to reload comments after mutations.
final projectCommentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, projectId) async {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.getComments(projectId);
});
