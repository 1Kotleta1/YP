import '../auth/permissions.dart';
import 'entity.dart';

/// Пользователь, вошедший в систему.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.viewerId,
    this.blocked = false,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final Role role;

  /// Для роли «зритель» — номер записи зрителя с его картой.
  final int? viewerId;
  final bool blocked;

  String get displayName => '$firstName $lastName'.trim().isEmpty ? username : '$firstName $lastName';

  bool can(Permission permission) => roleCan(role, permission);

  AppUser copyWith({Role? role, bool? blocked}) => AppUser(
    id: id,
    username: username,
    firstName: firstName,
    lastName: lastName,
    role: role ?? this.role,
    viewerId: viewerId,
    blocked: blocked ?? this.blocked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'firstName': firstName,
    'lastName': lastName,
    'role': role.code,
    'viewerId': viewerId,
    'blocked': blocked,
  };

  /// Неизвестная роль трактуется как самая слабая — зритель.
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: jsonInt(json['id']),
    username: jsonString(json['username']),
    firstName: jsonString(json['firstName']),
    lastName: jsonString(json['lastName']),
    role: Role.fromCode(json['role']) ?? Role.viewer,
    viewerId: json['viewerId'] is int ? json['viewerId'] as int : null,
    blocked: json['blocked'] == true,
  );
}

/// Ответ на вход, регистрацию и обновление токена.
class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: jsonString(json['accessToken']),
    refreshToken: jsonString(json['refreshToken']),
    user: AppUser.fromJson((json['user'] as Map).cast<String, dynamic>()),
  );
}

/// Запись в истории карты зрителя: посещение или продление абонемента.
class CardEvent {
  const CardEvent({required this.type, required this.delta, required this.at, required this.by});

  final String type;
  final int delta;
  final DateTime? at;
  final String by;

  bool get isVisit => type == 'visit';

  factory CardEvent.fromJson(Map<String, dynamic> json) => CardEvent(
    type: jsonString(json['type']),
    delta: jsonInt(json['delta']),
    at: jsonDate(json['at']),
    by: jsonString(json['by']),
  );
}
