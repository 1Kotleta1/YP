// Адаптер демонстрационного режима есть только в браузере;
// в тестах и на других платформах подключается заглушка.
export 'demo_adapter_stub.dart' if (dart.library.js_interop) 'demo_adapter_web.dart';
