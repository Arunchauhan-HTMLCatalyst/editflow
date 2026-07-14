class ReviewVideo {
  final String id;
  final String reviewId;
  final String name;
  final String url;
  final DateTime createdAt;

  const ReviewVideo({
    required this.id,
    required this.reviewId,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  factory ReviewVideo.fromJson(Map<String, dynamic> json) => ReviewVideo(
        id: json['id'] as String,
        reviewId: json['review_id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'review_id': reviewId,
        'name': name,
        'url': url,
        'created_at': createdAt.toIso8601String(),
      };

  ReviewVideo copyWith({
    String? id,
    String? reviewId,
    String? name,
    String? url,
    DateTime? createdAt,
  }) =>
      ReviewVideo(
        id: id ?? this.id,
        reviewId: reviewId ?? this.reviewId,
        name: name ?? this.name,
        url: url ?? this.url,
        createdAt: createdAt ?? this.createdAt,
      );
}
