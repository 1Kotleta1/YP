import 'entity.dart';

class Director implements Entity {
  @override
  final int id;
  final String lastName;
  final String firstName;
  final String country;
  final int birthYear;
  @override
  final DateTime? deletedAt;

  const Director({
    required this.id,
    required this.lastName,
    required this.firstName,
    required this.country,
    required this.birthYear,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  String get fullName => '$firstName $lastName';

  Director copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? country,
    int? birthYear,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Director(
      id: id ?? this.id,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      country: country ?? this.country,
      birthYear: birthYear ?? this.birthYear,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lastName': lastName,
    'firstName': firstName,
    'country': country,
    'birthYear': birthYear,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Director.fromJson(Map<String, dynamic> json) => Director(
    id: jsonInt(json['id']),
    lastName: jsonString(json['lastName']),
    firstName: jsonString(json['firstName']),
    country: jsonString(json['country']),
    birthYear: jsonInt(json['birthYear']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}
