import 'package:flutter/material.dart';

import 'state_views.dart';

/// Экран из библиотеки, подключённой через `deferred as`.
///
/// Код таких экранов не входит в main.dart.js: браузер скачивает его
/// отдельным файлом при первом переходе. Пока файл грузится, виден
/// индикатор; если загрузка не удалась — сообщение и кнопка повтора.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.library, required this.load, required this.builder});

  /// Имя части сборки: по нему запоминается, что она уже загружена.
  final String library;
  final Future<void> Function() load;
  final WidgetBuilder builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  // Загруженную часть второй раз не ждём — иначе индикатор мелькал бы
  // при каждом переходе
  static final _loaded = <String>{};

  Object? _error;

  @override
  void initState() {
    super.initState();
    if (!_loaded.contains(widget.library)) _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      await widget.load();
      _loaded.add(widget.library);
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded.contains(widget.library)) return widget.builder(context);
    return Material(
      child: _error == null
          ? const LoadingView()
          : ErrorView(message: 'Не удалось загрузить раздел. Проверьте соединение.', onRetry: _load),
    );
  }
}
