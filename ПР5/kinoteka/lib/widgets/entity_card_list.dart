import 'package:flutter/material.dart';

/// Список карточек для узкого окна — замена [EntityTable] при ширине < 600.
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
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = idOf(item);
        final deleted = isDeleted?.call(item) ?? false;
        return Card(
          margin: EdgeInsets.zero,
          color: deleted ? scheme.errorContainer.withValues(alpha: 0.35) : null,
          child: ListTile(
            leading: onToggleSelect == null
                ? null
                : Checkbox(
                    value: selected.contains(id),
                    onChanged: (_) => onToggleSelect!(id),
                  ),
            title: title(item),
            subtitle: subtitle(item),
            onTap: onOpen == null ? null : () => onOpen!(item),
            trailing: actions == null
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
          ),
        );
      },
    );
  }
}
