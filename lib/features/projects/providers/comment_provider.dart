import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';

final projectCommentsProvider = StreamProvider.family<List<Comment>, String>((ref, projectId) {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.subscribeComments(projectId);
});
