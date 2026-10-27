import 'package:flutter/material.dart';

enum DeleteMode { soft, hard }

/// Подтверждение удаления. Возвращает выбранный вид удаления или null.
///
/// [allowSoft] = false, когда запись уже в корзине и остаётся только
/// удалить её навсегда. [allowHard] = false, когда роль пользователя
/// не позволяет удалять навсегда (такое право есть только у администратора).
Future<DeleteMode?> confirmDelete(
  BuildContext context, {
  required String what,
  bool allowSoft = true,
  bool allowHard = true,
}) {
  return showDialog<DeleteMode>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Удаление'),
      content: Text(switch ((allowSoft, allowHard)) {
        (true, true) => 'Удалить $what?\n\n«В корзину» — запись скрывается из списка и её '
            'можно восстановить. «Навсегда» — запись стирается полностью.',
        (true, false) => 'Переместить $what в корзину? Восстановить запись сможет администратор.',
        _ => 'Удалить $what навсегда? Восстановить запись будет нельзя.',
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (allowHard)
          TextButton(
            onPressed: () => Navigator.pop(context, DeleteMode.hard),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Навсегда'),
          ),
        if (allowSoft)
          FilledButton(
            onPressed: () => Navigator.pop(context, DeleteMode.soft),
            child: const Text('В корзину'),
          ),
      ],
    ),
  );
}

/// Сервер отказал по правам (403): интерфейс мог показать кнопку, но решение
/// принимает сервер по роли из подписанного токена.
Future<void> showForbidden(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.gpp_bad_outlined, color: Theme.of(context).colorScheme.error),
      title: const Text('Доступ запрещён (403)'),
      content: Text('$message\n\nСервер отклонил операцию: права проверяются '
          'по роли из подписанного токена, а не по данным в браузере.'),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно')),
      ],
    ),
  );
}

/// Сервер отказал (409) — объясняем причину, например число связанных записей.
Future<void> showDeleteBlocked(BuildContext context, String message,
    {String title = 'Удаление невозможно'}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.link, color: Theme.of(context).colorScheme.error),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно')),
      ],
    ),
  );
}
