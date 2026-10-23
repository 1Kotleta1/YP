import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // debugPrint

import 'api_debug.dart';
import 'api_exceptions.dart';
import 'config.dart';

/// Настроенный клиент Dio: адрес, таймауты и цепочка интерсепторов.
///
/// Порядок интерсепторов важен:
///   1. служебные параметры учебного сервера (__delay, __fail);
///   2. журнал — метод, адрес, код ответа и время;
///   3. разбор кодов 4xx в исключения предметной области;
///   4. повтор операций чтения при сетевом сбое.
Dio buildDio({
  String baseUrl = apiBaseUrl,
  ApiDebugFlags? debugFlags,
  String? Function()? tokenProvider,
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
        if (debugFlags != null && options.extra['attempt'] == null) {
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
    RetryInterceptor(dio, baseDelay: retryDelay, log: logging),
  ]);

  return dio;
}

/// Журнал запросов: в консоли браузера видно метод, адрес, код и время.
class LogApiInterceptor extends Interceptor {
  static const _startKey = 'startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
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
    final started = o.extra[_startKey];
    final ms = started is DateTime ? DateTime.now().difference(started).inMilliseconds : 0;
    debugPrint('[API] ${o.method} ${o.uri} → $result ($ms мс)');
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
