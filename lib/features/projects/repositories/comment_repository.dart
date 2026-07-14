import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    final createdComment = Comment.fromJson(response);

    // Dynamic Realtime Notification for Comments
    unawaited(() async {
      try {
        // Use separate queries to avoid PostgREST schema cache join errors
        final projectRes = await SupabaseService.instance
            .from('projects')
            .select('name, user_id, client_id')
            .eq('id', comment.projectId)
            .single()
            .timeout(const Duration(seconds: 10));

        final projectName = projectRes['name'] as String? ?? 'Project';
        final freelancerUserId = projectRes['user_id'] as String?;
        final clientId = projectRes['client_id'] as String?;

        // Fetch client_user_id separately
        String? clientUserId;
        if (clientId != null && clientId.isNotEmpty) {
          try {
            final clientRes = await SupabaseService.instance
                .from('clients')
                .select('client_user_id')
                .eq('id', clientId)
                .maybeSingle()
                .timeout(const Duration(seconds: 10));
            clientUserId = clientRes?['client_user_id'] as String?;
          } catch (e) {
            debugPrint('[COMMENT NOTIFICATION] Failed to fetch client user id: $e');
          }
        }

        final isFreelancerAuthor = comment.userId == freelancerUserId;
        final notifyUserId = isFreelancerAuthor ? clientUserId : freelancerUserId;

        if (notifyUserId != null && notifyUserId.isNotEmpty) {
          final authorName = comment.userName.isNotEmpty ? comment.userName : (isFreelancerAuthor ? 'Freelancer' : 'Client');
          String desc;
          if (comment.voiceUrl != null) {
            desc = '$authorName sent a voice note on project "$projectName"';
          } else {
            final truncatedContent = comment.content.length > 40
                ? '${comment.content.substring(0, 40)}...'
                : comment.content;
            desc = '$authorName: "$truncatedContent" on "$projectName"';
          }

          await SupabaseService.instance.from('activities').insert({
            'user_id': notifyUserId,
            'type': 'comment_created',
            'description': desc,
            'reference_id': comment.projectId,
            'reference_type': 'project',
            'created_at': DateTime.now().toIso8601String(),
          }).timeout(const Duration(seconds: 10));
          debugPrint('[COMMENT NOTIFICATION] Inserted activity for $notifyUserId: $desc');
        }
      } catch (e) {
        debugPrint('[COMMENT NOTIFICATION ERROR] $e');
      }
    }());

    return createdComment;
  }

  Stream<List<Comment>> subscribeComments(String projectId) {
    try {
      return SupabaseService.instance
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('project_id', projectId)
          .map((rows) {
            debugPrint('[COMMENT STREAM] got ${rows.length} rows');
            final list = rows.map((e) => Comment.fromJson(e)).toList();
            list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return list;
          });
    } catch (e) {
      debugPrint('[CommentRepository] subscribeComments failed, returning empty stream: $e');
      return const Stream.empty();
    }
  }

  /// Uploads a compressed voice note file to Supabase Storage.
  Future<String> uploadVoiceNote(String projectId, String filePath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_$projectId.m4a';
    final storagePath = 'projects/$projectId/$fileName';

    debugPrint('[CommentRepository] Uploading voice note to storage: $storagePath');
    
    if (kIsWeb) {
      final XFile xFile = XFile(filePath);
      final bytes = await xFile.readAsBytes();
      await SupabaseService.instance.storage
          .from('voice-notes')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: 'audio/aac'),
          );
    } else {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Recording file not found: $filePath');
      }
      await SupabaseService.instance.storage
          .from('voice-notes')
          .upload(storagePath, file);
    }

    final publicUrl = SupabaseService.instance.storage
        .from('voice-notes')
        .getPublicUrl(storagePath);

    debugPrint('[CommentRepository] Upload complete. Public URL: $publicUrl');
    return publicUrl;
  }

  /// Finds and deletes voice notes created more than 14 days ago.
  Future<void> cleanupOldVoiceNotes() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
      debugPrint('[CommentRepository] Starting cleanup sweep for comments older than 14 days ($cutoffDate)');

      final response = await SupabaseService.instance
          .from('comments')
          .select('id, voice_url')
          .lt('created_at', cutoffDate)
          .not('voice_url', 'is', null);

      final oldComments = response as List;
      if (oldComments.isEmpty) {
        debugPrint('[CommentRepository] No voice notes eligible for cleanup.');
        return;
      }

      debugPrint('[CommentRepository] Found ${oldComments.length} voice notes to delete.');
      final List<String> relativePathsToDelete = [];
      final List<String> commentIdsToUpdate = [];

      for (final comment in oldComments) {
        final commentId = comment['id'] as String;
        final voiceUrl = comment['voice_url'] as String?;
        if (voiceUrl == null) continue;

        commentIdsToUpdate.add(commentId);

        // Parse relative path in bucket from public URL
        try {
          final uri = Uri.parse(voiceUrl);
          final segments = uri.pathSegments;
          final idx = segments.indexOf('voice-notes');
          if (idx != -1 && idx + 1 < segments.length) {
            final relPath = segments.sublist(idx + 1).join('/');
            relativePathsToDelete.add(relPath);
          }
        } catch (e) {
          debugPrint('[CommentRepository] Failed to parse voice_url relative path ($voiceUrl): $e');
        }
      }

      // 1. Delete actual files from Supabase Storage
      if (relativePathsToDelete.isNotEmpty) {
        debugPrint('[CommentRepository] Deleting storage files: $relativePathsToDelete');
        try {
          await SupabaseService.instance.storage
              .from('voice-notes')
              .remove(relativePathsToDelete);
        } catch (e) {
          debugPrint('[CommentRepository] Storage deletion error: $e');
        }
      }

      // 2. Set database fields to null to prevent client from trying to load them
      if (commentIdsToUpdate.isNotEmpty) {
        debugPrint('[CommentRepository] Clearing database rows for comment IDs: $commentIdsToUpdate');
        await SupabaseService.instance
            .from('comments')
            .update({'voice_url': null, 'voice_duration': null})
            .inFilter('id', commentIdsToUpdate);
      }

      debugPrint('[CommentRepository] Cleanup completed successfully.');
    } catch (e, st) {
      debugPrint('[CommentRepository] Cleanup error: $e\n$st');
    }
  }

  Future<Comment> update(String commentId, String content, String userId) async {
    // Filter only by comment id — Supabase RLS enforces ownership.
    // Using .select() returning a list avoids PGRST116 (406) from .single()/.maybeSingle().
    final list = await SupabaseService.instance
        .from('comments')
        .update({'content': content})
        .eq('id', commentId)
        .select()
        .timeout(const Duration(seconds: 15));
    if (list.isEmpty) {
      throw Exception('Comment not found or you do not have permission to edit it.');
    }
    return Comment.fromJson((list as List).first);
  }

  Future<void> delete(String commentId, String userId) async {
    // Delete any voice note file from storage first if applicable
    try {
      final response = await SupabaseService.instance
          .from('comments')
          .select('voice_url')
          .eq('id', commentId)
          .maybeSingle();
      final voiceUrl = response?['voice_url'] as String?;
      if (voiceUrl != null && voiceUrl.isNotEmpty) {
        final uri = Uri.parse(voiceUrl);
        final segments = uri.pathSegments;
        final idx = segments.indexOf('voice-notes');
        if (idx != -1 && idx + 1 < segments.length) {
          final relPath = segments.sublist(idx + 1).join('/');
          await SupabaseService.instance.storage
              .from('voice-notes')
              .remove([relPath]);
        }
      }
    } catch (e) {
      debugPrint('[CommentRepository] Failed to delete voice note during comment deletion: $e');
    }

    final list = await SupabaseService.instance
        .from('comments')
        .delete()
        .eq('id', commentId)
        .select()
        .timeout(const Duration(seconds: 15));

    if (list.isEmpty) {
      throw Exception('Comment not found or you do not have permission to delete it.');
    }
  }
}

final commentRepositoryProvider = Provider<CommentRepository>((ref) => CommentRepository());
