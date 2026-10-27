import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../repositories/api_repository.dart' show asMap;

/// Открытые адреса сервера: вход, регистрация, обновление токена, выход.
///
/// Работает через отдельный Dio без интерсептора обновления токена:
/// ответ 401 на /auth/login означает «неверный пароль», и пытаться
/// обновлять токен в ответ на него нельзя — получится бесконечный цикл.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login(String username, String password) => guard(() async {
    final r = await _dio.post<dynamic>('/auth/login', data: {'username': username.trim(), 'password': password});
    return AuthSession.fromJson(asMap(r.data));
  });

  Future<AuthSession> register({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/register',
      data: {
        'username': username.trim(),
        'password': password,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
      },
    );
    return AuthSession.fromJson(asMap(r.data));
  });

  Future<AuthSession> refresh(String refreshToken) => guard(() async {
    final r = await _dio.post<dynamic>('/auth/refresh', data: {'refreshToken': refreshToken});
    return AuthSession.fromJson(asMap(r.data));
  });

  /// Текущий пользователь по токену доступа.
  Future<AppUser> me(String accessToken) => guard(() async {
    final r = await _dio.get<dynamic>('/auth/me', options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
    return AppUser.fromJson(asMap(r.data));
  });

  /// Отзыв токена обновления на сервере. Ошибки не важны: выход
  /// на клиенте выполняется в любом случае.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<dynamic>('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
  }
}
