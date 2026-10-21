/// Имитация сети для репозиториев в памяти.
///
/// Задержка нужна, чтобы индикатор загрузки был виден (в ПР4 он
/// понадобится по-настоящему), а флаг [failNext] позволяет вручную
/// проверить экран ошибки.
class NetworkSimulator {
  NetworkSimulator({this.delay = const Duration(milliseconds: 250)});

  final Duration delay;
  bool _failNext = false;

  /// Следующий запрос завершится ошибкой.
  void failNext() => _failNext = true;

  Future<void> call() async {
    await Future.delayed(delay);
    if (_failNext) {
      _failNext = false;
      throw const NetworkException('сервер не отвечает (имитация сбоя)');
    }
  }
}

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}
