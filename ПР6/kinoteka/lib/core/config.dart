import 'package:flutter/foundation.dart';

/// Адрес сервера задаётся только при сборке, в коде адресов нет:
/// на занятии он один, дома другой, при публикации третий.
///
///   flutter run -d edge --web-port=5555 --dart-define-from-file=env/local.json
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com/api
///
/// Значение demo включает демонстрационный режим опубликованной сборки:
/// логика учебного сервера выполняется в браузере (см. DemoAdapter).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Демонстрационный режим: сервера нет, api-core.js работает в браузере.
const isDemoApi = apiBaseUrl == 'demo';

/// Журнал запросов в консоли браузера. По умолчанию — только в отладке;
/// для релизной сборки включается флагом --dart-define=API_LOG=true.
const apiLogging = bool.fromEnvironment('API_LOG', defaultValue: kDebugMode);

const connectTimeout = Duration(seconds: 10);
const receiveTimeout = Duration(seconds: 15);

/// Повтор при сетевом сбое: всего не более трёх попыток.
const maxReadAttempts = 3;
const retryBaseDelay = Duration(milliseconds: 400);

/// Пока связи с сервером нет, его доступность проверяется с этим интервалом.
const healthCheckInterval = Duration(seconds: 3);

/// Выход по неактивности: через три минуты без действий пользователя,
/// предупреждение — за 30 секунд. Для проверки срок можно сократить:
///   --dart-define=INACTIVITY_SECONDS=45
const inactivityTimeout = Duration(seconds: int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180));
const inactivityWarning = Duration(seconds: 30);

/// Наибольшая длительность сессии независимо от активности (8 часов).
///   --dart-define=SESSION_MAX_MINUTES=5
const sessionMaxDuration = Duration(minutes: int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 480));
