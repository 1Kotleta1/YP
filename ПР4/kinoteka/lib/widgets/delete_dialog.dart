import 'package:flutter/material.dart';

enum DeleteMode { soft, hard }

/// Подтверждение удаления. Возвращает выбранный вид удаления или null.
///
/// [allowSoft] = false, когда запись уже в корзине и остаётся только
/// удалить её навсегда.
Future<DeleteMode?> confirmDelete(
  BuildContext context, {
  required String what,
  bool allowSoft = true,
}) {
  return showDialog<DeleteMode>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Удаление'),
      content: Text(allowSoft
          ? 'Удалить $what?\n\n«В корзину» — запись скрывается из списка и её '
              'можно восстановить. «Навсегда» — запись стирается полностью.'
          : 'Удалить $what навсегда? Восстановить запись будет нельзя.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
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
