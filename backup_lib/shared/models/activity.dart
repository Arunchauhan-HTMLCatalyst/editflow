class Activity {
  final String id;
  final String userId;
  final String type;
  final String description;
  final String? referenceId;
  final String? referenceType;
  final DateTime createdAt;

  const Activity({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    this.referenceId,
    this.referenceType,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String,
        description: json['description'] as String,
        referenceId: json['reference_id'] as String?,
        referenceType: json['reference_type'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'description': description,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'created_at': createdAt.toIso8601String(),
      };
}
