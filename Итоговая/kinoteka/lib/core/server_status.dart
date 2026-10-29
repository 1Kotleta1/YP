import 'dart:async';

import 'package:flutter/foundation.dart';

/// Есть ли связь с сервером.
///
/// Сетевой сбой (после всех повторов) переводит состояние в «нет связи»,
/// и с этого момента сервер опрашивается адресом /__health. Как только он
/// ответил, слушатели узнают об этом и сами перезагружают данные —
/// перезагружать страницу пользователю не нужно.
class ServerStatus extends ChangeNotifier {
  ServerStatus(this._ping, {this.interval = const Duration(seconds: 3)});

  final Future<bool> Function() _ping;
  final Duration interval;
  Timer? _timer;
  bool _online = true;
  bool _checking = false;

  bool get online => _online;

  /// Запрос не дошёл до сервера.
  void reportFailure() {
    if (!_online) return;
    _online = false;
    notifyListeners();
    _timer = Timer.periodic(interval, (_) => check());
  }

  /// Сервер ответил — значит, связь есть.
  void reportSuccess() {
    if (!_online) _setOnline();
  }

  /// Проверить связь сейчас (кнопка на баннере и опрос по таймеру).
  Future<void> check() async {
    if (_online || _checking) return;
    _checking = true;
    try {
      if (await _ping()) _setOnline();
    } finally {
      _checking = false;
    }
  }

  void _setOnline() {
    _timer?.cancel();
    _timer = null;
    _online = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
