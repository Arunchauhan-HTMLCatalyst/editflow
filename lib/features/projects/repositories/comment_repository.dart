import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../../../services/supabase_service.dart';

class CommentRepository {
  Future<List<Comment>> getComments(String projectId) async {
    final response = await SupabaseService.instance
        .from('comments')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: true)
        .timeout(const Duration(seconds: 15));
    return (response as List).map((e) => Comment.fromJson(e)).toList();
  }

  Future<Comment> create(Comment comment) async {
    final data = comment.toJson()..remove('id');
    final response = await SupabaseService.instance
        .from('comments')
        .insert(data)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return Comment.fromJson(response);
  }

  Stream<List<Comment>> subscribeComments(String projectId) {
    try {
      return SupabaseService.instance
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('project_id', projectId)
          .order('created_at', ascending: true)
          .map((rows) {
            debugPrint('[COMMENT STREAM] got ${rows.length} rows');
            return rows.map((e) => Comment.fromJson(e)).toList();
          });
    } catch (e) {
      debugPrint('[CommentRepository] subscribeComments failed, returning empty stream: $e');
      return const Stream.empty();
    }
  }
}

final commentRepositoryProvider = Provider<CommentRepository>((ref) => CommentRepository());
