import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/entity.dart';
import '../models/viewer.dart';
import 'api_repository.dart' show asMap;

/// Своя карта зрителя и её история.
class MyCard {
  const MyCard(this.viewer, this.history);

  final Viewer viewer;
  final List<CardEvent> history;

  factory MyCard.fromJson(Map<String, dynamic> json) => MyCard(
    Viewer.fromJson(asMap(json['viewer'])),
    json['history'] is List ? [for (final e in json['history'] as List) CardEvent.fromJson(asMap(e))] : const [],
  );
}

/// Сводка для администратора.
class AppStats {
  const AppStats(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> _map(String key) => raw[key] is Map ? asMap(raw[key]) : const {};

  int alive(String collection) => jsonInt(asMap(_map('collections')[collection])['total']);
  int deleted(String collection) => jsonInt(asMap(_map('collections')[collection])['deleted']);
  int usersWithRole(String role) => jsonInt(_map('users')[role]);
  int get blockedUsers => jsonInt(raw['blockedUsers']);
  int get visitsTotal => jsonInt(raw['visitsTotal']);
  int get visitsWeek => jsonInt(raw['visitsWeek']);
  int get visitsLeft => jsonInt(raw['visitsLeft']);
  int get activeSessions => jsonInt(raw['activeSessions']);
}

/// Адреса, которые зависят от вошедшего пользователя.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<MyCard> myCard() => guard(() async {
    final r = await _dio.get<dynamic>('/me/card');
    return MyCard.fromJson(asMap(r.data));
  });

  Future<MyCard> renewCard() => guard(() async {
    final r = await _dio.post<dynamic>('/me/card/renew');
    return MyCard.fromJson(asMap(r.data));
  });

  Future<List<AppUser>> users() => guard(() async {
    final r = await _dio.get<dynamic>('/users');
    return [for (final u in r.data as List) AppUser.fromJson(asMap(u))];
  });

  Future<AppUser> updateUser(int id, {String? role, bool? blocked}) => guard(() async {
    final r = await _dio.put<dynamic>('/users/$id', data: {'role': ?role, 'blocked': ?blocked});
    return AppUser.fromJson(asMap(r.data));
  });

  Future<AppStats> stats() => guard(() async {
    final r = await _dio.get<dynamic>('/stats');
    return AppStats(asMap(r.data));
  });
}
