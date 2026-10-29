import 'package:flutter/foundation.dart';

/// Служебные параметры для проверки состояний экрана: ?__delay=1500 —
/// задержка ответа, ?__fail=500 — ответ с ошибкой. Supabase их не знает,
/// поэтому задержку и сбой имитирует клиент (см. api_client.dart).
///
/// Значения можно задать в адресе страницы при открытии приложения
/// (http://localhost:5555/movies?__delay=1500) или из меню «Проверка».
class ApiDebugFlags extends ChangeNotifier {
  ApiDebugFlags({int? delayMs, int? failStatus}) : _delayMs = delayMs, _failAlways = failStatus;

  factory ApiDebugFlags.fromPageUrl(Uri uri) => ApiDebugFlags(
    delayMs: int.tryParse(uri.queryParameters['__delay'] ?? ''),
    failStatus: int.tryParse(uri.queryParameters['__fail'] ?? ''),
  );

  int? _delayMs;
  int? _failAlways;
  int? _failNext;

  int? get delayMs => _delayMs;

  set delayMs(int? value) {
    _delayMs = value;
    notifyListeners();
  }

  /// Ошибка у каждого запроса — задана в адресе страницы.
  int? get failAlways => _failAlways;

  void clearFailAlways() {
    _failAlways = null;
    notifyListeners();
  }

  /// Следующий запрос (и только он) получит ответ с этим кодом.
  void failNext([int status = 500]) => _failNext = status;

  /// Параметры для очередного запроса; разовый сбой при этом расходуется.
  Map<String, String> takeParameters() {
    final fail = _failNext ?? _failAlways;
    _failNext = null;
    return {if (_delayMs != null) '__delay': '$_delayMs', if (fail != null) '__fail': '$fail'};
  }
}
