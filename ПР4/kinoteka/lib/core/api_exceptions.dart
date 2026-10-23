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

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String) ? body['message'] as String : null;

  return switch (status) {
    400 => BadRequestException(message ?? 'Некорректный запрос.'),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(message ?? 'Недостаточно прав для этого действия.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
        message ?? 'Ошибка валидации',
        (body is Map && body['errors'] is Map)
            ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : const {},
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
    DioExceptionType.receiveTimeout =>
      const NetworkException('Сервер не ответил вовремя.'),
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
