class Review {
  final String id;
  final String projectId;
  final String status; // 'draft', 'pending', 'changes_requested', 'approved'
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.projectId,
    required this.status,
    this.submittedAt,
    this.approvedAt,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        status: json['status'] as String? ?? 'draft',
        submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at'] as String) : null,
        approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'status': status,
        'submitted_at': submittedAt?.toIso8601String(),
        'approved_at': approvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  Review copyWith({
    String? id,
    String? projectId,
    String? status,
    DateTime? submittedAt,
    DateTime? approvedAt,
    DateTime? createdAt,
  }) =>
      Review(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        status: status ?? this.status,
        submittedAt: submittedAt ?? this.submittedAt,
        approvedAt: approvedAt ?? this.approvedAt,
        createdAt: createdAt ?? this.createdAt,
      );
}
