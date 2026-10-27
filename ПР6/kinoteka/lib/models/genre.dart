import 'entity.dart';

class Genre implements Entity {
  static const categories = ['Игровое кино', 'Анимация', 'Документальное'];

  @override
  final int id;
  final String name;
  final String category;
  final String description;
  @override
  final DateTime? deletedAt;

  const Genre({required this.id, required this.name, required this.category, this.description = '', this.deletedAt});

  @override
  bool get isDeleted => deletedAt != null;

  Genre copyWith({
    int? id,
    String? name,
    String? category,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Genre(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: jsonInt(json['id']),
    name: jsonString(json['name']),
    category: jsonString(json['category'], categories.first),
    description: jsonString(json['description']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}
