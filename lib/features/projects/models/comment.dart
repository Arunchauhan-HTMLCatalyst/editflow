import 'package:flutter/foundation.dart';

class Comment {
  final String id;
  final String projectId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final String? voiceUrl;
  final int? voiceDuration;

  const Comment({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.voiceUrl,
    this.voiceDuration,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? 'User',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        voiceUrl: json['voice_url'] as String?,
        voiceDuration: json['voice_duration'] as int?,
      );

  static Comment? tryFromJson(Map<String, dynamic> json) {
    try {
      return Comment.fromJson(json);
    } catch (e) {
      debugPrint('[Comment.tryFromJson] Failed to parse row: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'user_id': userId,
        'user_name': userName,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'voice_url': voiceUrl,
        'voice_duration': voiceDuration,
      };

  Comment copyWith({
    String? id,
    String? projectId,
    String? userId,
    String? userName,
    String? content,
    DateTime? createdAt,
    String? voiceUrl,
    int? voiceDuration,
  }) =>
      Comment(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        voiceUrl: voiceUrl ?? this.voiceUrl,
        voiceDuration: voiceDuration ?? this.voiceDuration,
      );
}
