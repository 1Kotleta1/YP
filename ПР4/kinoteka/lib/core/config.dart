import 'package:flutter/foundation.dart';

/// Адрес сервера задаётся при сборке, а не константой в коде:
/// на занятии он один, дома другой, при публикации третий.
///
///   flutter run -d edge --web-port=5555 --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Журнал запросов в консоли браузера. По умолчанию — только в отладке;
/// для релизной сборки включается флагом --dart-define=API_LOG=true.
const apiLogging = bool.fromEnvironment('API_LOG', defaultValue: kDebugMode);

const connectTimeout = Duration(seconds: 10);
const receiveTimeout = Duration(seconds: 15);

/// Повтор при сетевом сбое: всего не более трёх попыток.
const maxReadAttempts = 3;
const retryBaseDelay = Duration(milliseconds: 400);
