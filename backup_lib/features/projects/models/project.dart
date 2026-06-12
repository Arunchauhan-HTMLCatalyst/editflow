import 'project_status.dart';

class Project {
  final String id;
  final String userId;
  final String clientId;
  final String name;
  final String? description;
  final double price;
  final double receivedAmount;
  final DateTime? deadline;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? clientName;

  const Project({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.name,
    this.description,
    required this.price,
    required this.receivedAmount,
    this.deadline,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
  });

  double get remainingAmount => price - receivedAmount;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        clientId: json['client_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: (json['price'] as num).toDouble(),
        receivedAmount: (json['received_amount'] as num).toDouble(),
        deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
        status: ProjectStatus.fromString(json['status'] as String? ?? 'created'),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        clientName: json['client_name'] as String?,
      );

  static Project? tryFromJson(Map<String, dynamic> json) {
    try {
      final clientName = json['clients'] is Map ? json['clients']['name'] as String? : null;
      if (clientName != null) json['client_name'] = clientName;
      return Project.fromJson(json);
    } catch (e) {
      print('[Project.tryFromJson] Failed to parse row: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'client_id': clientId,
        'name': name,
        'description': description,
        'price': price,
        'received_amount': receivedAmount,
        'deadline': deadline?.toIso8601String(),
        'status': status.value,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Project copyWith({
    String? id,
    String? userId,
    String? clientId,
    String? name,
    String? description,
    double? price,
    double? receivedAmount,
    DateTime? deadline,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientName,
  }) =>
      Project(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        clientId: clientId ?? this.clientId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        receivedAmount: receivedAmount ?? this.receivedAmount,
        deadline: deadline ?? this.deadline,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        clientName: clientName ?? this.clientName,
      );
}
