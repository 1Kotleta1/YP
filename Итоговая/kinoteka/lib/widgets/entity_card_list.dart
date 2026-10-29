import 'package:flutter/material.dart';

/// Список карточек вместо [EntityTable] на узком и среднем окне.
/// [columns] — 1 на телефоне, 2 на планшете.
class EntityCardList<T> extends StatelessWidget {
  final List<T> items;
  final int Function(T item) idOf;
  final Widget Function(T item) title;
  final Widget Function(T item) subtitle;
  final bool Function(T item)? isDeleted;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final ValueChanged<T>? onOpen;
  final List<Widget> Function(T item)? actions;
  final int columns;

  const EntityCardList({
    super.key,
    required this.items,
    required this.idOf,
    required this.title,
    required this.subtitle,
    this.isDeleted,
    this.selected = const {},
    this.onToggleSelect,
    this.onOpen,
    this.actions,
    this.columns = 1,
  });

  Widget _card(BuildContext context, T item) {
    final scheme = Theme.of(context).colorScheme;
    final id = idOf(item);
    final deleted = isDeleted?.call(item) ?? false;
    final color = deleted ? scheme.errorContainer.withValues(alpha: 0.35) : null;
    if (columns > 1) return _gridCard(context, item, id, color);
    return Card(
      margin: EdgeInsets.zero,
      color: color,
      child: ListTile(
        leading: onToggleSelect == null
            ? null
            : Checkbox(value: selected.contains(id), onChanged: (_) => onToggleSelect!(id)),
        // Длинное название обрезается многоточием, а не ломает карточку
        title: DefaultTextStyle.merge(maxLines: 1, overflow: TextOverflow.ellipsis, child: title(item)),
        subtitle: DefaultTextStyle.merge(maxLines: 2, overflow: TextOverflow.ellipsis, child: subtitle(item)),
        onTap: onOpen == null ? null : () => onOpen!(item),
        trailing: actions == null ? null : Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
      ),
    );
  }

  /// Карточка в сетке из нескольких колонок: она узкая, поэтому кнопки
  /// стоят под текстом, а не отнимают у названия место справа.
  Widget _gridCard(BuildContext context, T item, int id, Color? color) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen == null ? null : () => onOpen!(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title(item),
              ),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                child: SizedBox(width: double.infinity, child: subtitle(item)),
              ),
              Row(
                children: [
                  if (onToggleSelect != null)
                    Checkbox(value: selected.contains(id), onChanged: (_) => onToggleSelect!(id)),
                  const Spacer(),
                  if (actions != null) ...actions!(item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (columns == 1) {
      return ListView.separated(
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _card(context, items[index]),
      );
    }
    // Строки сетки: карточки одной строки одинаковой высоты
    const gap = 8.0;
    final rows = (items.length + columns - 1) ~/ columns;
    return ListView.separated(
      padding: padding,
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: gap),
      itemBuilder: (context, row) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = row * columns; i < row * columns + columns; i++) ...[
              if (i > row * columns) const SizedBox(width: gap),
              Expanded(child: i < items.length ? _card(context, items[i]) : const SizedBox()),
            ],
          ],
        ),
      ),
    );
  }
}
