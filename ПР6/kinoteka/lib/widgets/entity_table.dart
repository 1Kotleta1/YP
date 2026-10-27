import 'package:flutter/material.dart';

/// Описание колонки таблицы: подпись, поле сортировки и построитель ячейки.
class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({required this.label, required this.build, this.sortField, this.numeric = false});
}

/// Обобщённая таблица для любой сущности.
///
/// Экраны отличаются только описанием колонок — выделение,
/// сортировка по заголовку и действия в строке реализованы здесь один раз.
class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final bool Function(T item)? isDeleted;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final ValueChanged<bool>? onToggleSelectAll;
  final ValueChanged<T>? onOpen;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.isDeleted,
    this.selected = const {},
    this.onToggleSelect,
    this.onToggleSelectAll,
    this.onOpen,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortIndex = columns.indexWhere((c) => c.sortField != null && c.sortField == sortField);

    final table = DataTable(
      showCheckboxColumn: onToggleSelect != null,
      columnSpacing: 28,
      sortColumnIndex: sortIndex == -1 ? null : sortIndex,
      sortAscending: sortAscending,
      headingTextStyle: theme.textTheme.titleSmall,
      onSelectAll: onToggleSelectAll == null ? null : (value) => onToggleSelectAll!(value ?? false),
      columns: [
        for (final c in columns)
          DataColumn(
            label: Text(c.label),
            numeric: c.numeric,
            onSort: c.sortField == null || onSort == null ? null : (_, _) => onSort!(c.sortField!),
          ),
        if (actions != null) const DataColumn(label: Text('Действия')),
      ],
      rows: [
        for (final item in items)
          DataRow(
            selected: selected.contains(idOf(item)),
            onSelectChanged: onToggleSelect == null ? null : (_) => onToggleSelect!(idOf(item)),
            color: isDeleted != null && isDeleted!(item)
                ? WidgetStatePropertyAll(theme.colorScheme.errorContainer.withValues(alpha: 0.35))
                : null,
            cells: [
              for (final c in columns)
                DataCell(
                  // Длинное название не растягивает таблицу, а обрезается
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: DefaultTextStyle.merge(maxLines: 2, overflow: TextOverflow.ellipsis, child: c.build(item)),
                  ),
                  onTap: onOpen == null ? null : () => onOpen!(item),
                ),
              if (actions != null) DataCell(Row(mainAxisSize: MainAxisSize.min, children: actions!(item))),
            ],
          ),
      ],
    );

    // Двумерная прокрутка: таблица не уезжает за край узкого окна.
    // Если места больше, чем нужно таблице, она растягивается на всю ширину
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: table,
            ),
          ),
        ),
      ),
    );
  }
}
