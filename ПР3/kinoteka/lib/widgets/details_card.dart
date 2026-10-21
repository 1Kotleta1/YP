import 'package:flutter/material.dart';

/// Карточка записи: заголовок, пары «поле — значение» и кнопки действий.
class DetailsCard extends StatelessWidget {
  const DetailsCard({
    super.key,
    required this.title,
    required this.rows,
    required this.actions,
    this.subtitle,
    this.deleted = false,
  });

  final String title;
  final String? subtitle;
  final bool deleted;
  final Map<String, Widget> rows;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (deleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Chip(
                        avatar: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('В корзине'),
                        backgroundColor: theme.colorScheme.errorContainer,
                      ),
                    ),
                  Text(title, style: theme.textTheme.headlineSmall),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    )),
                  const Divider(height: 32),
                  for (final e in rows.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(e.key, style: theme.textTheme.labelLarge),
                          ),
                          Expanded(child: e.value),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 12, runSpacing: 8, children: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
