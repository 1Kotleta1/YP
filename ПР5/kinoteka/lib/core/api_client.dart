import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // debugPrint

import 'api_debug.dart';
import 'api_exceptions.dart';
import 'config.dart';

/// Настроенный клиент Dio: адрес, таймауты и цепочка интерсепторов.
///
/// Порядок интерсепторов важен:
///   1. заголовок Authorization и служебные параметры учебного сервера;
///   2. журнал — метод, адрес, код ответа и время;
///   3. разбор кодов 4xx в исключения предметной области;
///   4. обновление токена и повтор запроса при ответе 401;
///   5. повтор операций чтения при сетевом сбое.
Dio buildDio({
  String baseUrl = apiBaseUrl,
  ApiDebugFlags? debugFlags,
  String? Function()? tokenProvider,
  Future<void> Function()? refreshToken,
  bool logging = apiLogging,
  Duration retryDelay = retryBaseDelay,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Content-Type': 'application/json'},
      // Не бросать исключение на кодах 4xx — разберём их сами
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.addAll([
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        if (debugFlags != null && options.extra['attempt'] == null && options.extra['authRetry'] == null) {
          options.queryParameters = {...options.queryParameters, ...debugFlags.takeParameters()};
        }
        return handler.next(options);
      },
    ),
    if (logging) LogApiInterceptor(),
    InterceptorsWrapper(
      onResponse: (response, handler) {
        // Коды 4xx попадают сюда, а не в onError, из-за validateStatus.
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          // Просто написать `throw mapHttpError(...)` нельзя: dio перехватит
          // исключение из интерсептора и завернёт его в DioException с типом
          // unknown. Поэтому отправляем ответ по ветке ошибок сами, приложив
          // уже разобранное исключение.
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
    ),
    if (refreshToken != null) AuthRefreshInterceptor(dio, refreshToken, log: logging),
    RetryInterceptor(dio, baseDelay: retryDelay, log: logging),
  ]);

  return dio;
}

/// Журнал запросов: в консоли браузера видно метод, адрес, код и время.
class LogApiInterceptor extends Interceptor {
  static const _startKey = 'startedAt';
  static const _loggedKey = 'logged';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    options.extra.remove(_loggedKey);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _print(response.requestOptions, '${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    _print(err.requestOptions, status != null ? '$status' : 'сбой: ${err.type.name}');
    handler.next(err);
  }

  void _print(RequestOptions o, String result) {
    // Ответ 4xx проходит и onResponse, и (после reject с
    // callFollowingErrorInterceptor) onError — печатаем его один раз.
    if (o.extra[_loggedKey] == true) return;
    o.extra[_loggedKey] = true;
    final started = o.extra[_startKey];
    final ms = started is DateTime ? DateTime.now().difference(started).inMilliseconds : 0;
    debugPrint('[API] ${o.method} ${o.uri} → $result ($ms мс)');
  }
}

/// Прозрачное обновление токена.
///
/// Токен доступа может истечь прямо во время работы. Получив 401, интерсептор
/// обновляет токен и повторяет исходный запрос — пользователь ничего не
/// замечает. Если обновить не удалось, AuthNotifier уже вывел пользователя
/// из системы, а запрос завершается ошибкой «сессия истекла».
///
/// Адреса /auth/ не обрабатываются: 401 на /auth/login означает неверный
/// пароль, и попытка обновить токен в ответ на него дала бы бесконечный цикл.
/// Повторный запрос помечается authRetry и второй раз токен не обновляет.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor(this._dio, this._refresh, {this.log = false});

  final Dio _dio;
  final Future<void> Function() _refresh;
  final bool log;

  static bool isUnauthorized(DioException e) =>
      e.error is UnauthorizedException || e.response?.statusCode == 401;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (!isUnauthorized(err) || options.path.contains('/auth/') || options.extra['authRetry'] == true) {
      return handler.next(err);
    }
    try {
      if (log) debugPrint('[API] 401 → обновление токена: ${options.method} ${options.uri}');
      await _refresh();
    } on ApiException {
      return handler.next(DioException(
        requestOptions: options,
        response: err.response,
        type: DioExceptionType.badResponse,
        error: const UnauthorizedException('Сессия истекла. Войдите снова.'),
      ));
    }
    options.extra['authRetry'] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Автоматический повтор при сетевом сбое.
///
/// Повторяются только операции чтения (GET): повторять POST нельзя —
/// если сервер успел создать запись, а ответ потерялся, появится дубликат.
/// Не более [maxAttempts] попыток с нарастающей паузой 400, 800 мс…
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxAttempts = maxReadAttempts,
    this.baseDelay = retryBaseDelay,
    this.log = false,
  });

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;
  final bool log;

  static bool isNetworkFailure(DioException e) => switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          true,
        _ => false,
      };

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra['attempt'] as int?) ?? 1;
    final retryable = options.method == 'GET' &&
        isNetworkFailure(err) &&
        !(options.cancelToken?.isCancelled ?? false);
    if (!retryable || attempt >= maxAttempts) return handler.next(err);

    final pause = baseDelay * (1 << (attempt - 1)); // 400, 800, 1600…
    if (log) debugPrint('[API] повтор ${attempt + 1}/$maxAttempts через ${pause.inMilliseconds} мс: ${options.uri}');
    await Future<void>.delayed(pause);
    if (options.cancelToken?.isCancelled ?? false) return handler.next(err);

    options.extra['attempt'] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
