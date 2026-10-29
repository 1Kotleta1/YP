import 'dart:convert';

import 'package:dio/dio.dart';

/// Исключения предметной области. Дальше репозиториев DioException
/// не выходит: экраны и формы знают только эти классы.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен, заблокировано CORS.
class NetworkException extends ApiException {
  const NetworkException([super.message = 'Сервер недоступен. Проверьте соединение.']);
}

/// Запрос отменён, потому что ушёл более новый (поиск по мере ввода).
class RequestCancelledException extends ApiException {
  const RequestCancelledException([super.message = 'Запрос отменён.']);
}

/// 400 — сервер не понял запрос.
class BadRequestException extends ApiException {
  const BadRequestException([super.message = 'Некорректный запрос.']);
}

/// 401 — не аутентифицирован либо срок действия токена истёк.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию.
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Недостаточно прав для этого действия.']);
}

/// 404.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности: удаление связанной записи,
/// посещение по карте без остатка.
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — ошибки валидации по полям. Ключи совпадают с именами полей модели.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);

  final Map<String, String> errors;
}

/// 5xx.
class ServerException extends ApiException {
  const ServerException([super.message = 'Ошибка на сервере. Попробуйте позже.']);
}

/// Ответ Supabase с ошибкой → код и тело в формате {message, errors}.
///
/// PostgREST (/rest/v1) отвечает {code, message, details, hint}. Функции и
/// триггеры базы поднимают ошибки с кодом PTxxx — PostgREST превращает его
/// в HTTP-код xxx, а у PT422 в details лежит JSON с ошибками по полям.
/// Supabase Auth (/auth/v1) отвечает {code, error_code, msg}.
(int, Map<String, dynamic>) normalizeSupabaseError(int status, dynamic body) {
  if (body is! Map) return (status, const {});
  final code = '${body['code'] ?? ''}';
  final authCode = '${body['error_code'] ?? body['error'] ?? ''}';
  final text = '${body['message'] ?? body['msg'] ?? body['error_description'] ?? ''}';

  if (code == 'PT422') {
    Map<String, dynamic> errors = const {};
    try {
      final decoded = jsonDecode('${body['details']}');
      if (decoded is Map) errors = decoded.cast<String, dynamic>();
    } catch (_) {}
    return (422, {'message': text, 'errors': errors});
  }
  if (code.startsWith('PT')) return (status, {'message': text});

  return switch ((code, authCode)) {
    // Нет прав на таблицу: у гостя — нужен вход, у вошедшего — не хватает роли
    ('42501', _) =>
      status == 401
          ? (401, {'message': 'Требуется вход в систему.'})
          : (403, {'message': 'Недостаточно прав для этого действия.'}),
    ('PGRST116', _) => (404, {'message': 'Запись не найдена.'}),
    ('PGRST301' || 'PGRST302' || 'PGRST303', _) => (401, {'message': 'Сессия истекла. Войдите снова.'}),
    ('23505', _) => (422, {'message': 'Такая запись уже есть.'}),
    ('23503', _) => (409, {'message': 'Операция невозможна: на запись ссылаются другие данные.'}),
    ('23514', _) => (422, {'message': 'Значение вне допустимого диапазона.'}),
    (_, 'invalid_credentials' || 'invalid_grant') => (401, {'message': 'Неверный логин или пароль.'}),
    (_, 'refresh_token_not_found' || 'refresh_token_already_used' || 'session_not_found') => (
      401,
      {'message': 'Сессия истекла. Войдите снова.'},
    ),
    (_, 'user_already_exists' || 'email_exists') => (
      422,
      {
        'message': 'Ошибка валидации',
        'errors': {'email': 'Пользователь с такой почтой уже зарегистрирован'},
      },
    ),
    (_, 'weak_password') => (
      422,
      {
        'message': 'Ошибка валидации',
        'errors': {'password': 'Пароль слишком простой'},
      },
    ),
    (_, 'email_address_invalid') => (
      422,
      {
        'message': 'Ошибка валидации',
        'errors': {'email': 'Неверный адрес почты, пример: name@mail.ru'},
      },
    ),
    (_, 'over_request_rate_limit' || 'over_email_send_rate_limit') => (
      409,
      {'message': 'Слишком много попыток. Подождите минуту и повторите.'},
    ),
    _ => (status, {'message': ?(text.isEmpty ? null : text), 'errors': ?body['errors']}),
  };
}

ApiException mapHttpError(int status, dynamic body) {
  (status, body) = normalizeSupabaseError(status, body);
  final message = (body is Map && body['message'] is String) ? body['message'] as String : null;

  return switch (status) {
    400 => BadRequestException(message ?? 'Некорректный запрос.'),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(message ?? 'Недостаточно прав для этого действия.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
      message ?? 'Ошибка валидации',
      (body is Map && body['errors'] is Map) ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v')) : const {},
    ),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

ApiException mapDioError(DioException e) {
  // Если исключение уже разобрал интерсептор, повторно его не разбираем.
  // Без этой проверки ошибка 422 придёт в приложение как ServerException,
  // и обработчик `on ValidationException` никогда не сработает.
  final existing = e.error;
  if (existing is ApiException) return existing;

  final status = e.response?.statusCode;
  if (e.type == DioExceptionType.badResponse && status != null) {
    return mapHttpError(status, e.response?.data);
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
      'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
    ),
    DioExceptionType.cancel => const RequestCancelledException(),
    _ => const ServerException(),
  };
}

/// Каждое обращение к сети проходит через guard: наружу выходят только
/// исключения предметной области, DioException остаётся внутри.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
