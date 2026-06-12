class Client {
  final String id;
  final String userId;
  final String name;
  final String? phone;
  final String? email;
  final String? company;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    this.email,
    this.company,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        company: json['company'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  static Client? tryFromJson(Map<String, dynamic> json) {
    try {
      return Client.fromJson(json);
    } catch (e) {
      print('[Client.tryFromJson] Failed to parse row: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'company': company,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Client copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? company,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Client(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        company: company ?? this.company,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
