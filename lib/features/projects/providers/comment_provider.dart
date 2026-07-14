import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';

/// A [StreamProvider] that listens to comments in real-time for a given project.
final projectCommentsProvider =
    StreamProvider.family<List<Comment>, String>((ref, projectId) {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.subscribeComments(projectId);
});
