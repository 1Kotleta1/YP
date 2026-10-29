import 'package:flutter/material.dart';

// Отдельный файл: диалог нужен маршрутизатору, а сами формы загружаются
// отложенно и в основную часть сборки не входят

/// Подтверждение ухода с формы с несохранёнными изменениями.
Future<bool> confirmLeave(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.edit_off_outlined),
      title: const Text('Несохранённые изменения'),
      content: const Text('Изменения в форме не сохранены. Уйти и потерять их?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Остаться')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Уйти')),
      ],
    ),
  );
  return result ?? false;
}
