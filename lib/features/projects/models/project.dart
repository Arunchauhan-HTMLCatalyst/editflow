import 'package:flutter/foundation.dart';
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
  final String? freelancerName;
  final String? freelancerUpiId;
  final String? reviewStatus;
  final String paymentType;
  final bool isFolder;
  final String? parentId;

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
    this.freelancerName,
    this.freelancerUpiId,
    this.reviewStatus,
    this.paymentType = 'project_basis',
    this.isFolder = false,
    this.parentId,
  });

  double get remainingAmount => price - receivedAmount;
  bool get isMonthly => paymentType == 'monthly';
  bool get isSubProject => parentId != null;

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
        freelancerName: json['freelancer_name'] as String?,
        freelancerUpiId: json['freelancer_upi_id'] as String?,
        reviewStatus: json['review_status'] as String?,
        paymentType: json['payment_type'] as String? ?? 'project_basis',
        isFolder: json['is_folder'] as bool? ?? false,
        parentId: json['parent_id'] as String?,
      );

  static Project? tryFromJson(Map<String, dynamic> json) {
    try {
      final clientName = json['clients'] is Map ? json['clients']['name'] as String? : null;
      if (clientName != null) json['client_name'] = clientName;
      final freelancerName = json['profiles'] is Map ? json['profiles']['full_name'] as String? : null;
      if (freelancerName != null) json['freelancer_name'] = freelancerName;
      final freelancerUpi = json['profiles'] is Map ? json['profiles']['upi_id'] as String? : null;
      if (freelancerUpi != null) json['freelancer_upi_id'] = freelancerUpi;
      
      // If reviews is joined in the response (e.g. for the latest review status)
      if (json['reviews'] is List && (json['reviews'] as List).isNotEmpty) {
        final latestReview = (json['reviews'] as List).first;
        if (latestReview is Map && latestReview['status'] != null) {
          json['review_status'] = latestReview['status'] as String;
        }
      } else if (json['reviews'] is Map && json['reviews']['status'] != null) {
        json['review_status'] = json['reviews']['status'] as String;
      }
      
      return Project.fromJson(json);
    } catch (e) {
      debugPrint('[Project.tryFromJson] Failed to parse row: $e');
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
        'client_name': clientName,
        'freelancer_name': freelancerName,
        'freelancer_upi_id': freelancerUpiId,
        'review_status': reviewStatus,
        'payment_type': paymentType,
        'is_folder': isFolder,
        'parent_id': parentId,
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
    String? freelancerName,
    String? freelancerUpiId,
    String? reviewStatus,
    String? paymentType,
    bool? isFolder,
    String? parentId,
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
        freelancerName: freelancerName ?? this.freelancerName,
        freelancerUpiId: freelancerUpiId ?? this.freelancerUpiId,
        reviewStatus: reviewStatus ?? this.reviewStatus,
        paymentType: paymentType ?? this.paymentType,
        isFolder: isFolder ?? this.isFolder,
        parentId: parentId ?? this.parentId,
      );
}
