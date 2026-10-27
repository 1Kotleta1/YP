import 'entity.dart';

/// Киностудия. Один ко многим: на одной студии снято много фильмов.
class Studio implements Entity {
  @override
  final int id;
  final String name;
  final String country;
  final int foundedYear;
  @override
  final DateTime? deletedAt;

  const Studio({
    required this.id,
    required this.name,
    required this.country,
    required this.foundedYear,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  Studio copyWith({
    int? id,
    String? name,
    String? country,
    int? foundedYear,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Studio(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      foundedYear: foundedYear ?? this.foundedYear,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'foundedYear': foundedYear,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Studio.fromJson(Map<String, dynamic> json) => Studio(
    id: jsonInt(json['id']),
    name: jsonString(json['name']),
    country: jsonString(json['country']),
    foundedYear: jsonInt(json['foundedYear']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}
