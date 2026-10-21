import 'entity.dart';

/// Зритель кинотеки. Один к одному: у каждого зрителя ровно одна карта.
class Viewer implements Entity {
  @override
  final int id;
  final String lastName;
  final String firstName;
  final String email;
  final String phone;
  final ViewerCard card;
  @override
  final DateTime? deletedAt;

  const Viewer({
    required this.id,
    required this.lastName,
    required this.firstName,
    required this.email,
    this.phone = '',
    required this.card,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  String get fullName => '$firstName $lastName';

  Viewer copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? email,
    String? phone,
    ViewerCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Viewer(
      id: id ?? this.id,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: card ?? this.card,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'lastName': lastName,
        'firstName': firstName,
        'email': email,
        'phone': phone,
        'card': card.toJson(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Viewer.fromJson(Map<String, dynamic> json) => Viewer(
        id: jsonInt(json['id']),
        lastName: jsonString(json['lastName']),
        firstName: jsonString(json['firstName']),
        email: jsonString(json['email']),
        phone: jsonString(json['phone']),
        card: json['card'] is Map
            ? ViewerCard.fromJson((json['card'] as Map).cast<String, dynamic>())
            : ViewerCard.empty,
        deletedAt: jsonDate(json['deletedAt']),
      );
}

/// Карта зрителя — хранится внутри записи зрителя, своего экрана нет.
class ViewerCard {
  static const tariffs = ['Базовый', 'Стандарт', 'Премиум'];
  static const empty = ViewerCard(number: '', tariff: 'Базовый', visitsLeft: 0, issuedAt: '');

  /// Номер карты в формате KT-123456.
  final String number;
  final String tariff;
  final int visitsLeft;

  /// Дата выдачи в формате ДД.ММ.ГГГГ.
  final String issuedAt;

  const ViewerCard({
    required this.number,
    required this.tariff,
    required this.visitsLeft,
    required this.issuedAt,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'tariff': tariff,
        'visitsLeft': visitsLeft,
        'issuedAt': issuedAt,
      };

  factory ViewerCard.fromJson(Map<String, dynamic> json) => ViewerCard(
        number: jsonString(json['number']),
        tariff: tariffs.contains(json['tariff']) ? json['tariff'] as String : tariffs.first,
        visitsLeft: jsonInt(json['visitsLeft']),
        issuedAt: jsonString(json['issuedAt']),
      );
}
