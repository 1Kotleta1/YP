import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Объект window.kinotekaDemo из web/demo/kinoteka-demo.js.
@JS('kinotekaDemo')
external _KinotekaDemo? get _demo;

extension type _KinotekaDemo._(JSObject _) implements JSObject {
  external JSPromise<JSString> handle(JSString method, JSString url, JSString headers, JSString? body);
}

/// Адаптер Dio для демонстрационного режима (API_BASE_URL=demo).
///
/// Запросы не уходят в сеть: их выполняет api-core.js — тот же код, что
/// у учебного сервера, — прямо в браузере. Интерсепторы, токены, коды
/// 401/403/409/422 и их обработка работают так же, как с сервером.
class DemoAdapter implements HttpClientAdapter {
  static Future<void>? _loading;

  /// Скрипты подгружаются при первом запросе, а не в index.html:
  /// обычной сборке с настоящим сервером они не нужны.
  static Future<void> _load() => _loading ??= () async {
    await _script('demo/api-core.js');
    await _script('demo/kinoteka-demo.js');
  }();

  static Future<void> _script(String src) {
    final done = Completer<void>();
    final document = globalContext['document']! as JSObject;
    final script = document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
    script['src'] = src.toJS;
    script['onload'] = (() => done.complete()).toJS;
    script['onerror'] = ((JSAny? _) => done.completeError(StateError('Не загружен $src'))).toJS;
    (document['head']! as JSObject).callMethod<JSAny?>('appendChild'.toJS, script);
    return done.future;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _load();
    String? body;
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      body = utf8.decode(bytes);
    }
    final headers = jsonEncode(options.headers.map((k, v) => MapEntry(k, '$v')));
    final raw = await _demo!.handle(options.method.toJS, options.uri.toString().toJS, headers.toJS, body?.toJS).toDart;
    final response = jsonDecode(raw.toDart) as Map<String, dynamic>;
    final data = response['body'];
    return ResponseBody.fromString(
      data == null ? '' : jsonEncode(data),
      response['status'] as int,
      headers: {
        if (data != null) Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
