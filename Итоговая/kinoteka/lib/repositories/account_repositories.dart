import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/entity.dart';
import '../models/viewer.dart';
import 'supabase_repositories.dart' show viewerJson;
import 'supabase_repository.dart' show asMap, camelKeys, rpc;

/// Своя карта зрителя и её история.
class MyCard {
  const MyCard(this.viewer, this.history);

  final Viewer viewer;
  final List<CardEvent> history;

  factory MyCard.fromJson(Map<String, dynamic> json) => MyCard(
    Viewer.fromJson(viewerJson(asMap(json['viewer']))),
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

/// Операции, которые зависят от вошедшего пользователя, — функции базы
/// (POST /rest/v1/rpc/…). Каждая сама проверяет право роли и без него
/// отвечает 403.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<MyCard> myCard() => guard(() async => MyCard.fromJson(asMap(await rpc(_dio, 'my_card'))));

  Future<MyCard> renewCard() => guard(() async => MyCard.fromJson(asMap(await rpc(_dio, 'renew_my_card'))));

  Future<List<AppUser>> users() => guard(() async {
    final data = await rpc(_dio, 'list_users');
    return [for (final u in data as List) AppUser.fromJson(camelKeys(asMap(u)))];
  });

  Future<AppUser> updateUser(int id, {String? role, bool? blocked}) => guard(() async {
    final data = await rpc(_dio, 'update_user', {'p_id': id, 'p_role': role, 'p_blocked': blocked});
    return AppUser.fromJson(camelKeys(asMap(data)));
  });

  Future<AppStats> stats() => guard(() async => AppStats(asMap(await rpc(_dio, 'stats'))));
}
