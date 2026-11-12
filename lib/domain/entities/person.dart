class Person {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;

  /// UPI ID (VPA) for paying them from a UPI app.
  final String? upiId;
  final String? avatarPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Person({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.upiId,
    this.avatarPath,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  Person copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    String? upiId,
    bool clearUpiId = false,
    String? avatarPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      upiId: clearUpiId ? null : (upiId ?? this.upiId),
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

