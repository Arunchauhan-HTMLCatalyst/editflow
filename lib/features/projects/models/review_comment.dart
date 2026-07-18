class ReviewComment {
  final String id;
  final String videoId;
  final int timestampMs; // Stored in milliseconds
  final String comment;
  final String authorId;
  final DateTime createdAt;
  final String? parentId;
  final Map<String, dynamic> reactions;
  final String taskStatus; // 'pending', 'in_progress', 'resolved'

  const ReviewComment({
    required this.id,
    required this.videoId,
    required this.timestampMs,
    required this.comment,
    required this.authorId,
    required this.createdAt,
    this.parentId,
    this.reactions = const {},
    this.taskStatus = 'pending',
  });

  bool get isResolved => taskStatus == 'resolved';

  factory ReviewComment.fromJson(Map<String, dynamic> json) => ReviewComment(
        id: json['id'] as String,
        videoId: json['video_id'] as String,
        timestampMs: (json['timestamp_ms'] as num).toInt(),
        comment: json['comment'] as String,
        authorId: json['author_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        parentId: json['parent_id'] as String?,
        reactions: json['reactions'] as Map<String, dynamic>? ?? const {},
        taskStatus: json['task_status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'video_id': videoId,
        'timestamp_ms': timestampMs,
        'comment': comment,
        'author_id': authorId,
        'created_at': createdAt.toIso8601String(),
        'parent_id': parentId,
        'reactions': reactions,
        'task_status': taskStatus,
      };

  ReviewComment copyWith({
    String? id,
    String? videoId,
    int? timestampMs,
    String? comment,
    String? authorId,
    DateTime? createdAt,
    String? parentId,
    Map<String, dynamic>? reactions,
    String? taskStatus,
  }) =>
      ReviewComment(
        id: id ?? this.id,
        videoId: videoId ?? this.videoId,
        timestampMs: timestampMs ?? this.timestampMs,
        comment: comment ?? this.comment,
        authorId: authorId ?? this.authorId,
        createdAt: createdAt ?? this.createdAt,
        parentId: parentId ?? this.parentId,
        reactions: reactions ?? this.reactions,
        taskStatus: taskStatus ?? this.taskStatus,
      );

  String get formattedTimestamp {
    final totalSeconds = timestampMs ~/ 1000;
    final ms = timestampMs % 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${(ms ~/ 100).toString()}';
  }
}
