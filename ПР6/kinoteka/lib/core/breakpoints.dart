import 'package:flutter/widgets.dart';

/// Классы ширины окна. Приложение проверяется при 360, 768, 1280 и 1920 px:
///
///   compact  < 600   одна колонка, навигация снизу, списки карточками;
///   medium   < 1024  боковая полоса навигации, карточки в две колонки;
///   expanded < 1600  таблицы, развёрнутая навигация с подписями;
///   large   ≥ 1600   то же, но содержимое ограничено по ширине.
enum WindowSize { compact, medium, expanded, large }

const compactMaxWidth = 600.0;
const tableMinWidth = 1024.0;
const largeMinWidth = 1600.0;

/// Наибольшая ширина содержимого на большом мониторе.
const contentMaxWidth = 1440.0;

WindowSize windowSizeFor(double width) {
  if (width < compactMaxWidth) return WindowSize.compact;
  if (width < tableMinWidth) return WindowSize.medium;
  if (width < largeMinWidth) return WindowSize.expanded;
  return WindowSize.large;
}

extension WindowSizeOf on BuildContext {
  /// Пересчитывается при каждом изменении размера окна — без перезагрузки.
  WindowSize get windowSize => windowSizeFor(MediaQuery.sizeOf(this).width);
}

extension WindowSizeCompare on WindowSize {
  bool operator >=(WindowSize other) => index >= other.index;
}
