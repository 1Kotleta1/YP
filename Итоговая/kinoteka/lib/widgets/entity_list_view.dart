import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/entity.dart';
import '../models/list_query.dart';
import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../state/paged_list_notifier.dart';
import 'delete_dialog.dart';
import 'entity_card_list.dart';
import 'entity_table.dart';
import 'pagination_bar.dart';
import 'state_views.dart';

/// Обобщённое тело экрана списка: состояния загрузки, таблица или карточки,
/// выделение и удаление, пагинация.
///
/// Любое изменение условий отбора уходит в [onNavigate] — экран переводит
/// его в адрес, а адрес уже применяется к состоянию.
class EntityListView<T extends Entity, Q extends ListQuery> extends StatelessWidget {
  const EntityListView({
    super.key,
    required this.notifier,
    required this.columns,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.isDeleted,
    required this.describe,
    required this.onOpen,
    required this.onNavigate,
    this.onEdit,
    this.editPermission = Permission.catalogEdit,
  });

  final PagedListNotifier<T, Q> notifier;
  final List<TableColumnSpec<T>> columns;
  final Widget Function(T item) cardTitle;
  final Widget Function(T item) cardSubtitle;
  final bool Function(T item) isDeleted;
  final String Function(T item) describe;
  final ValueChanged<T> onOpen;
  final ValueChanged<Q> onNavigate;
  final ValueChanged<T>? onEdit;

  /// Право на создание, изменение и удаление в корзину для этого списка.
  final Permission editPermission;

  Q get _query => notifier.query;

  void _sort(String field) {
    final ascending = field == _query.sortField ? !_query.sortAscending : true;
    onNavigate(_query.withSort(field, ascending) as Q);
  }

  Future<void> _deleteOne(BuildContext context, T item) async {
    final deleted = isDeleted(item);
    final auth = context.read<AuthNotifier>();
    final mode = await confirmDelete(
      context,
      what: '«${describe(item)}»',
      allowSoft: !deleted && auth.can(editPermission),
      allowHard: auth.can(Permission.recordsHardDelete),
    );
    if (mode == null || !context.mounted) return;
    final ok = await _guarded(context, () => notifier.delete(notifier.idOf(item), permanent: mode == DeleteMode.hard));
    if (ok && context.mounted) {
      _snack(
        context,
        mode == DeleteMode.hard
            ? '«${describe(item)}» удалён(а) навсегда'
            : '«${describe(item)}» перемещён(а) в корзину',
      );
    }
  }

  Future<void> _restore(BuildContext context, T item) async {
    final ok = await _guarded(context, () => notifier.restore(notifier.idOf(item)));
    if (ok && context.mounted) _snack(context, '«${describe(item)}» восстановлен(а)');
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final n = notifier.selected.length;
    final mode = await confirmDelete(
      context,
      what: 'выбранные записи ($n)',
      allowHard: context.read<AuthNotifier>().can(Permission.recordsHardDelete),
    );
    if (mode == null || !context.mounted) return;
    var count = 0;
    final ok = await _guarded(context, () async {
      count = await notifier.deleteSelected(permanent: mode == DeleteMode.hard);
    });
    if (ok && context.mounted) _snack(context, 'Удалено записей: $count');
  }

  /// Выполняет действие. Запрет сервера из-за связанных записей (409)
  /// и по правам (403) показывается диалогом, прочие ошибки — сообщением
  /// внизу экрана.
  Future<bool> _guarded(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on ConflictException catch (e) {
      if (context.mounted) await showDeleteBlocked(context, e.message);
      return false;
    } on ForbiddenException catch (e) {
      if (context.mounted) await showForbidden(context, e.message);
      return false;
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, 'Операция не выполнена: $e');
      return false;
    }
  }

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Кнопки строки. Недоступные роли действия не показываются вовсе —
  /// это уборка интерфейса, а не защита: защиту выполняет сервер.
  List<Widget> _actions(BuildContext context, T item) {
    final auth = context.watch<AuthNotifier>();
    final canEdit = auth.can(editPermission);
    final canHard = auth.can(Permission.recordsHardDelete);
    if (isDeleted(item)) {
      return [
        if (auth.can(Permission.recordsRestore))
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore_from_trash),
            onPressed: () => _restore(context, item),
          ),
        if (canHard)
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _deleteOne(context, item),
          ),
      ];
    }
    return [
      if (onEdit != null && canEdit)
        IconButton(tooltip: 'Изменить', icon: const Icon(Icons.edit_outlined), onPressed: () => onEdit!(item)),
      IconButton(tooltip: 'Открыть карточку', icon: const Icon(Icons.open_in_new), onPressed: () => onOpen(item)),
      if (canEdit || canHard)
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteOne(context, item),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Таблица — от 1024 px, ниже — карточки (на планшете в две колонки)
        final size = context.windowSize;
        final narrow = !(size >= WindowSize.expanded);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notifier.hasSelection)
              _SelectionBar(
                count: notifier.selected.length,
                onClear: notifier.clearSelection,
                onDelete: () => _deleteSelected(context),
              ),
            if (narrow)
              _NarrowSortBar<T>(
                columns: columns,
                field: _query.sortField,
                ascending: _query.sortAscending,
                onChanged: (field, asc) => onNavigate(_query.withSort(field, asc) as Q),
              ),
            Expanded(child: _content(context, narrow, size == WindowSize.medium ? 2 : 1)),
            if (notifier.status == LoadStatus.success && notifier.result.total > 0)
              PaginationBar(
                result: notifier.result,
                onPage: (p) => onNavigate(_query.withPage(p) as Q),
                onSize: (s) => onNavigate(_query.withSize(s) as Q),
              ),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, bool narrow, int cardColumns) {
    final items = notifier.result.items;
    switch (notifier.status) {
      case LoadStatus.idle:
        return const LoadingView();
      case LoadStatus.loading when items.isEmpty:
        return const LoadingView();
      case LoadStatus.error:
        return ErrorView(message: notifier.error ?? '', onRetry: notifier.load);
      case LoadStatus.success when items.isEmpty:
        return EmptyView(
          message: _query.hasFilters ? 'По заданным условиям записей нет. Измените поиск или фильтры.' : 'Список пуст.',
          onReset: _query.hasFilters ? () => onNavigate(_query.cleared() as Q) : null,
        );
      case LoadStatus.loading:
      case LoadStatus.success:
        break;
    }

    final selected = notifier.selected;
    // Флажки для множественного удаления — только у тех, кто может удалять
    final canSelect = context.watch<AuthNotifier>().can(editPermission);
    final view = narrow
        ? EntityCardList<T>(
            items: items,
            idOf: notifier.idOf,
            title: cardTitle,
            subtitle: cardSubtitle,
            isDeleted: isDeleted,
            selected: selected,
            onToggleSelect: canSelect ? notifier.toggleSelection : null,
            onOpen: onOpen,
            actions: (item) => _actions(context, item),
            columns: cardColumns,
          )
        : EntityTable<T>(
            columns: columns,
            items: items,
            idOf: notifier.idOf,
            isDeleted: isDeleted,
            selected: selected,
            onToggleSelect: canSelect ? notifier.toggleSelection : null,
            onToggleSelectAll: canSelect ? notifier.setPageSelection : null,
            onOpen: onOpen,
            sortField: _query.sortField,
            sortAscending: _query.sortAscending,
            onSort: _sort,
            actions: (item) => _actions(context, item),
          );

    // Повторная загрузка поверх старых данных: список не мигает
    return Stack(
      children: [
        Positioned.fill(child: view),
        if (notifier.status == LoadStatus.loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onClear, required this.onDelete});

  final int count;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            'Выбрано: $count',
            style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
          ),
          TextButton(onPressed: onClear, child: const Text('Снять выделение')),
          FilledButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Удалить выбранные'),
          ),
        ],
      ),
    );
  }
}

/// В режиме карточек заголовков колонок нет — сортировка выбирается списком.
class _NarrowSortBar<T> extends StatelessWidget {
  const _NarrowSortBar({required this.columns, required this.field, required this.ascending, required this.onChanged});

  final List<TableColumnSpec<T>> columns;
  final String field;
  final bool ascending;
  final void Function(String field, bool ascending) onChanged;

  @override
  Widget build(BuildContext context) {
    final sortable = columns.where((c) => c.sortField != null).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Сортировка:'),
          const SizedBox(width: 8),
          // Список полей занимает остаток строки и обрезает длинные подписи
          Flexible(
            child: DropdownButton<String>(
              value: field,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in sortable)
                  DropdownMenuItem(
                    value: c.sortField,
                    child: Text(c.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v, true);
              },
            ),
          ),
          IconButton(
            tooltip: ascending ? 'По возрастанию' : 'По убыванию',
            icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => onChanged(field, !ascending),
          ),
        ],
      ),
    );
  }
}
