import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Заглушка для платформ без JavaScript: демонстрационный режим недоступен.
class DemoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      throw UnsupportedError('Демонстрационный режим работает только в браузере');

  @override
  void close({bool force = false}) {}
}
