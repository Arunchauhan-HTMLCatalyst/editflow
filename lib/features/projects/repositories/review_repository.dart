import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../models/review.dart';
import '../models/review_video.dart';
import '../models/review_comment.dart';
import '../models/review_share.dart';

class ReviewRepository {
  Future<Review?> getLatestReview(String projectId) async {
    try {
      final response = await SupabaseService.instance
          .from('reviews')
          .select('*')
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      
      if (response == null) return null;
      return Review.fromJson(response);
    } catch (e) {
      debugPrint('[ReviewRepository.getLatestReview] Error: $e');
      return null;
    }
  }

  Future<List<ReviewVideo>> getReviewVideos(String reviewId) async {
    try {
      final response = await SupabaseService.instance
          .from('review_videos')
          .select('*')
          .eq('review_id', reviewId)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 10));
      
      return (response as List)
          .map((e) => ReviewVideo.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[ReviewRepository.getReviewVideos] Error: $e');
      return [];
    }
  }

  Future<List<ReviewComment>> getReviewComments(String videoId) async {
    try {
      final response = await SupabaseService.instance
          .from('review_comments')
          .select('*')
          .eq('video_id', videoId)
          .order('timestamp_ms', ascending: true)
          .timeout(const Duration(seconds: 10));
      
      return (response as List)
          .map((e) => ReviewComment.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[ReviewRepository.getReviewComments] Error: $e');
      return [];
    }
  }

  /// Transactionally submits a new review version
  Future<void> submitNewReview(String projectId, List<Map<String, String>> videos) async {
    // 1. Fetch current active review (if any) to check if we are replacing or submitting first time
    final oldReview = await getLatestReview(projectId);
    final isReplacement = oldReview != null;

    // 2. Create a new review record with status 'pending'
    final newReviewRes = await SupabaseService.instance
        .from('reviews')
        .insert({
          'project_id': projectId,
          'status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select('*')
        .single()
        .timeout(const Duration(seconds: 15));

    final newReview = Review.fromJson(newReviewRes);

    try {
      // 3. Insert all review videos linked to this new review
      final videoRows = videos.map((v) => {
        'review_id': newReview.id,
        'name': v['name'],
        'url': v['url'],
      }).toList();

      await SupabaseService.instance
          .from('review_videos')
          .insert(videoRows)
          .timeout(const Duration(seconds: 15));

      // 4. Clean up the previous review (cascade deletes old videos and comments)
      if (oldReview != null) {
        await SupabaseService.instance
            .from('reviews')
            .delete()
            .eq('id', oldReview.id)
            .timeout(const Duration(seconds: 15));
      }

      // 5. Update the project status to 'review_pending'
      await SupabaseService.instance
          .from('projects')
          .update({
            'status': 'review_pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', projectId)
          .timeout(const Duration(seconds: 10));

      // 6. Log notification/activity event
      // Find client assigned to the project to notify them
      final projectRes = await SupabaseService.instance
          .from('projects')
          .select('name, client_id')
          .eq('id', projectId)
          .single()
          .timeout(const Duration(seconds: 10));
      
      final clientRes = await SupabaseService.instance
          .from('clients')
          .select('name, client_user_id')
          .eq('id', projectRes['client_id'])
          .single()
          .timeout(const Duration(seconds: 10));

      final clientUserId = clientRes['client_user_id'] as String?;
      final projectName = projectRes['name'] as String;

      if (clientUserId != null && clientUserId.isNotEmpty) {
        await SupabaseService.instance.from('activities').insert({
          'user_id': clientUserId,
          'type': isReplacement ? 'review_replaced' : 'review_submitted',
          'description': isReplacement
              ? 'Freelancer uploaded a new review revision for "$projectName"'
              : 'Freelancer submitted review videos for "$projectName"',
          'reference_id': projectId,
          'reference_type': 'project',
          'created_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 10));
      }

    } catch (e) {
      // Clean up the draft new review record if something failed during video insertions
      try {
        await SupabaseService.instance
            .from('reviews')
            .delete()
            .eq('id', newReview.id)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      
      debugPrint('[ReviewRepository.submitNewReview] Failed and aborted: $e');
      rethrow;
    }
  }

  Future<void> addReviewComment(ReviewComment comment) async {
    await SupabaseService.instance
        .from('review_comments')
        .insert(comment.toJson()..remove('id'))
        .timeout(const Duration(seconds: 10));
  }

  Future<void> submitReviewFeedback(String reviewId) async {
    // 1. Update review status to 'changes_requested'
    final reviewRes = await SupabaseService.instance
        .from('reviews')
        .update({
          'status': 'changes_requested',
        })
        .eq('id', reviewId)
        .select('project_id')
        .single()
        .timeout(const Duration(seconds: 10));

    final projectId = reviewRes['project_id'] as String;

    // 2. Set project status to 'revision_pending'
    await SupabaseService.instance
        .from('projects')
        .update({
          'status': 'revision_pending',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', projectId)
        .timeout(const Duration(seconds: 10));

    // 3. Log notification for the freelancer
    try {
      final projectRes = await SupabaseService.instance
          .from('projects')
          .select('name, user_id')
          .eq('id', projectId)
          .single()
          .timeout(const Duration(seconds: 10));

      final freelancerUserId = projectRes['user_id'] as String;
      final projectName = projectRes['name'] as String;

      await SupabaseService.instance.from('activities').insert({
        'user_id': freelancerUserId,
        'type': 'review_feedback_submitted',
        'description': 'Client submitted review feedback for "$projectName"',
        'reference_id': projectId,
        'reference_type': 'project',
        'created_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[ReviewRepository.submitReviewFeedback] Activity log failed: $e');
    }
  }

  Future<void> approveReview(String reviewId) async {
    // 1. Update review status to 'approved' and approved_at timestamp
    final reviewRes = await SupabaseService.instance
        .from('reviews')
        .update({
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId)
        .select('project_id')
        .single()
        .timeout(const Duration(seconds: 10));

    final projectId = reviewRes['project_id'] as String;

    // Note: We do NOT update project status to completed here!
    // The freelancer does it manually after checking the confirmation dialog.

    // 2. Log activity for the freelancer
    try {
      final projectRes = await SupabaseService.instance
          .from('projects')
          .select('name, user_id')
          .eq('id', projectId)
          .single()
          .timeout(const Duration(seconds: 10));

      final freelancerUserId = projectRes['user_id'] as String;
      final projectName = projectRes['name'] as String;

      await SupabaseService.instance.from('activities').insert({
        'user_id': freelancerUserId,
        'type': 'review_approved',
        'description': 'Client approved the review for "$projectName"',
        'reference_id': projectId,
        'reference_type': 'project',
        'created_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[ReviewRepository.approveReview] Activity log failed: $e');
    }
  }

  String _generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (i) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> createShareLink(String reviewId, int? expiryHours) async {
    try {
      final token = _generateToken();
      final expiresAt = expiryHours != null
          ? DateTime.now().toUtc().add(Duration(hours: expiryHours))
          : null;

      await SupabaseService.instance.from('review_shares').insert({
        'review_id': reviewId,
        'token': token,
        'expires_at': expiresAt?.toIso8601String(),
        'created_by': SupabaseService.userId,
      });
      return token;
    } catch (e) {
      debugPrint('[ReviewRepository.createShareLink] Error: $e');
      rethrow;
    }
  }

  Future<ReviewShare?> getReviewShare(String token) async {
    try {
      final response = await SupabaseService.instance
          .from('review_shares')
          .select('*')
          .eq('token', token)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) return null;
      return ReviewShare.fromJson(response);
    } catch (e) {
      debugPrint('[ReviewRepository.getReviewShare] Error: $e');
      return null;
    }
  }

  Future<Review?> getReviewByShareToken(String token, String reviewId) async {
    final client = SupabaseService.instance;
    try {
      client.rest.headers['x-share-token'] = token;
      final response = await client
          .from('reviews')
          .select('*')
          .eq('id', reviewId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) return null;
      return Review.fromJson(response);
    } catch (e) {
      debugPrint('[ReviewRepository.getReviewByShareToken] Error: $e');
      return null;
    } finally {
      client.rest.headers.remove('x-share-token');
    }
  }

  Future<List<ReviewVideo>> getReviewVideosByShareToken(String token, String reviewId) async {
    final client = SupabaseService.instance;
    try {
      client.rest.headers['x-share-token'] = token;
      final response = await client
          .from('review_videos')
          .select('*')
          .eq('review_id', reviewId)
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((e) => ReviewVideo.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[ReviewRepository.getReviewVideosByShareToken] Error: $e');
      return [];
    } finally {
      client.rest.headers.remove('x-share-token');
    }
  }

  Future<List<ReviewComment>> getReviewCommentsByShareToken(String token, String videoId) async {
    final client = SupabaseService.instance;
    try {
      client.rest.headers['x-share-token'] = token;
      final response = await client
          .from('review_comments')
          .select('*')
          .eq('video_id', videoId)
          .order('timestamp_ms', ascending: true)
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((e) => ReviewComment.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[ReviewRepository.getReviewCommentsByShareToken] Error: $e');
      return [];
    } finally {
      client.rest.headers.remove('x-share-token');
    }
  }

  Future<void> addReviewCommentByShareToken(String token, ReviewComment comment) async {
    final client = SupabaseService.instance;
    try {
      client.rest.headers['x-share-token'] = token;
      await client
          .from('review_comments')
          .insert(comment.toJson()..remove('id'))
          .timeout(const Duration(seconds: 10));
    } finally {
      client.rest.headers.remove('x-share-token');
    }
  }
}
