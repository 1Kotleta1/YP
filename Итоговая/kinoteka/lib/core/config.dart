import 'package:flutter/foundation.dart';

/// Проект Supabase задаётся только при сборке, в коде адресов и ключей нет:
///
///   flutter run -d edge --web-port=5555 --dart-define-from-file=env/supabase.json
///   flutter build web --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_…
///
/// SUPABASE_KEY — публикуемый (publishable, anon) ключ проекта. Он и так
/// виден любому посетителю сайта: доступ к данным ограничивают правила RLS
/// в базе, а не секретность ключа. Секретный ключ service_role в клиент
/// не попадает никогда.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

/// Адрес, относительно которого строятся пути /rest/v1/… и /auth/v1/….
const apiBaseUrl = supabaseUrl;

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
