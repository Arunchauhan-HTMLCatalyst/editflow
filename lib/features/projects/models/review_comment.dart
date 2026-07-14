class ReviewComment {
  final String id;
  final String videoId;
  final int timestampMs; // Stored in milliseconds
  final String comment;
  final String authorId;
  final DateTime createdAt;

  const ReviewComment({
    required this.id,
    required this.videoId,
    required this.timestampMs,
    required this.comment,
    required this.authorId,
    required this.createdAt,
  });

  factory ReviewComment.fromJson(Map<String, dynamic> json) => ReviewComment(
        id: json['id'] as String,
        videoId: json['video_id'] as String,
        timestampMs: (json['timestamp_ms'] as num).toInt(),
        comment: json['comment'] as String,
        authorId: json['author_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'video_id': videoId,
        'timestamp_ms': timestampMs,
        'comment': comment,
        'author_id': authorId,
        'created_at': createdAt.toIso8601String(),
      };

  ReviewComment copyWith({
    String? id,
    String? videoId,
    int? timestampMs,
    String? comment,
    String? authorId,
    DateTime? createdAt,
  }) =>
      ReviewComment(
        id: id ?? this.id,
        videoId: videoId ?? this.videoId,
        timestampMs: timestampMs ?? this.timestampMs,
        comment: comment ?? this.comment,
        authorId: authorId ?? this.authorId,
        createdAt: createdAt ?? this.createdAt,
      );

  String get formattedTimestamp {
    final totalSeconds = timestampMs ~/ 1000;
    final ms = timestampMs % 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${(ms ~/ 100).toString()}';
  }
}
