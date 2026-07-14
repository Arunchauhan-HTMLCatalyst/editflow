class ReviewShare {
  final String id;
  final String reviewId;
  final String token;
  final DateTime? expiresAt;
  final String createdBy;
  final DateTime createdAt;

  const ReviewShare({
    required this.id,
    required this.reviewId,
    required this.token,
    this.expiresAt,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory ReviewShare.fromJson(Map<String, dynamic> json) => ReviewShare(
        id: json['id'] as String,
        reviewId: json['review_id'] as String,
        token: json['token'] as String,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        createdBy: json['created_by'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'review_id': reviewId,
        'token': token,
        'expires_at': expiresAt?.toIso8601String(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  ReviewShare copyWith({
    String? id,
    String? reviewId,
    String? token,
    DateTime? expiresAt,
    String? createdBy,
    DateTime? createdAt,
  }) =>
      ReviewShare(
        id: id ?? this.id,
        reviewId: reviewId ?? this.reviewId,
        token: token ?? this.token,
        expiresAt: expiresAt ?? this.expiresAt,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
      );
}
