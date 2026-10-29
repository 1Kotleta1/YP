import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/entity.dart';
import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/simple_query.dart';
import '../models/studio.dart';
import '../models/viewer.dart';
import '../state/lookups.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_panel.dart';

/// Фильтр-выпадающий список по одному ключу [SimpleQuery.filters].
class FilterOption {
  const FilterOption(this.key, this.label, this.allLabel, this.options);

  final String key;
  final String label;
  final String allLabel;
  final List<String> options;
}

/// Описание экрана списка справочной сущности.
class SimpleListConfig<T extends Entity> {
  const SimpleListConfig({
    required this.section,
    required this.path,
    required this.title,
    required this.addLabel,
    required this.searchLabel,
    required this.deletedLabel,
    required this.columns,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.describe,
    this.filters = _noFilters,
    this.editPermission = Permission.catalogEdit,
  });

  final AppSection section;
  final String path;
  final String title;
  final String addLabel;
  final String searchLabel;
  final String deletedLabel;
  final List<TableColumnSpec<T>> columns;
  final Widget Function(T item) cardTitle;
  final Widget Function(T item) cardSubtitle;
  final String Function(T item) describe;
  final List<FilterOption> Function(Lookups lookups) filters;

  /// Право на создание, изменение и удаление в корзину.
  final Permission editPermission;

  static List<FilterOption> _noFilters(Lookups _) => const [];
}

/// Один экран для жанров, киностудий и зрителей: поиск, фильтр, сортировка,
/// пагинация, удаление и восстановление — всё из ПР2, без копирования кода.
class SimpleListScreen<T extends Entity> extends StatefulWidget {
  const SimpleListScreen({super.key, required this.config, required this.query});

  final SimpleListConfig<T> config;
  final SimpleQuery query;

  @override
  State<SimpleListScreen<T>> createState() => _SimpleListScreenState<T>();
}

class _SimpleListScreenState<T extends Entity> extends State<SimpleListScreen<T>> {
  @override
  void initState() {
    super.initState();
    _applyFromUrl();
  }

  @override
  void didUpdateWidget(covariant SimpleListScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _applyFromUrl();
  }

  void _applyFromUrl() {
    final query = widget.query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PagedListNotifier<T, SimpleQuery>>().applyQuery(query);
    });
  }

  void _navigate(SimpleQuery next) => context.go(listLocation(widget.config.path, next));

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final notifier = context.watch<PagedListNotifier<T, SimpleQuery>>();
    final filters = c.filters(context.watch<Lookups>());
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return AppShell(
      section: c.section,
      title: c.title,
      onReload: notifier.load,
      onAdd: auth.can(c.editPermission) ? () => context.go('${c.path}/new') : null,
      addLabel: c.addLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterPanel(
            activeCount: (q.search.isNotEmpty ? 1 : 0) + q.filters.length,
            children: [
              DebouncedTextField(
                width: 300,
                label: c.searchLabel,
                icon: Icons.search,
                value: q.search,
                onChanged: (v) => _navigate(q.copyWith(search: v)),
              ),
              for (final f in filters)
                FilterDropdown<String>(
                  label: f.label,
                  allLabel: f.allLabel,
                  value: q.filter(f.key),
                  options: {for (final o in f.options) o: o},
                  onChanged: (v) => _navigate(q.copyWith(filters: {f.key: v})),
                ),
              if (auth.can(Permission.trashView))
                FilterChip(
                  label: Text(c.deletedLabel),
                  selected: q.includeDeleted,
                  onSelected: (v) => _navigate(q.copyWith(includeDeleted: v)),
                ),
              if (q.hasFilters)
                TextButton.icon(
                  onPressed: () => _navigate(q.cleared()),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
            ],
          ),
          Expanded(
            child: EntityListView<T, SimpleQuery>(
              notifier: notifier,
              onNavigate: _navigate,
              onOpen: (e) => context.go('${c.path}/${e.id}'),
              onEdit: (e) => context.go('${c.path}/${e.id}/edit'),
              editPermission: c.editPermission,
              isDeleted: (e) => e.isDeleted,
              describe: c.describe,
              cardTitle: c.cardTitle,
              cardSubtitle: c.cardSubtitle,
              columns: c.columns,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _strike(bool deleted) =>
    TextStyle(fontWeight: FontWeight.w600, decoration: deleted ? TextDecoration.lineThrough : null);

final genreListConfig = SimpleListConfig<Genre>(
  section: AppSection.genres,
  path: '/genres',
  title: 'Кинотека — жанры',
  addLabel: 'Новый жанр',
  searchLabel: 'Поиск по названию или описанию',
  deletedLabel: 'Показывать удалённые',
  describe: (g) => g.name,
  cardTitle: (g) => Text(g.name),
  cardSubtitle: (g) => Text('${g.category}\n${g.description}'),
  filters: (_) => const [FilterOption('category', 'Категория', 'Все категории', Genre.categories)],
  columns: [
    TableColumnSpec(
      label: 'Название',
      sortField: 'name',
      build: (g) => Text(g.name, style: _strike(g.isDeleted)),
    ),
    TableColumnSpec(label: 'Категория', sortField: 'category', build: (g) => Text(g.category)),
    TableColumnSpec(label: 'Описание', build: (g) => Text(g.description)),
  ],
);

final studioListConfig = SimpleListConfig<Studio>(
  section: AppSection.studios,
  path: '/studios',
  title: 'Кинотека — киностудии',
  addLabel: 'Новая студия',
  searchLabel: 'Поиск по названию или стране',
  deletedLabel: 'Показывать удалённые',
  describe: (s) => s.name,
  cardTitle: (s) => Text(s.name),
  cardSubtitle: (s) => Text('${s.country} · основана в ${s.foundedYear} г.'),
  filters: (l) => [FilterOption('country', 'Страна', 'Все страны', l.studioCountries)],
  columns: [
    TableColumnSpec(
      label: 'Название',
      sortField: 'name',
      build: (s) => Text(s.name, style: _strike(s.isDeleted)),
    ),
    TableColumnSpec(label: 'Страна', sortField: 'country', build: (s) => Text(s.country)),
    TableColumnSpec(
      label: 'Год основания',
      sortField: 'foundedYear',
      numeric: true,
      build: (s) => Text('${s.foundedYear}'),
    ),
  ],
);

final viewerListConfig = SimpleListConfig<Viewer>(
  section: AppSection.viewers,
  path: '/viewers',
  title: 'Кинотека — зрители',
  addLabel: 'Новый зритель',
  searchLabel: 'Поиск по фамилии, почте или карте',
  deletedLabel: 'Показывать удалённых',
  editPermission: Permission.viewersManage,
  describe: (v) => v.fullName,
  cardTitle: (v) => Text('${v.lastName} ${v.firstName}'),
  cardSubtitle: (v) => Text('${v.email}\n${v.card.number} · ${v.card.tariff} · посещений: ${v.card.visitsLeft}'),
  filters: (_) => const [FilterOption('tariff', 'Тариф', 'Все тарифы', ViewerCard.tariffs)],
  columns: [
    TableColumnSpec(
      label: 'Фамилия',
      sortField: 'lastName',
      build: (v) => Text(v.lastName, style: _strike(v.isDeleted)),
    ),
    TableColumnSpec(label: 'Имя', sortField: 'firstName', build: (v) => Text(v.firstName)),
    TableColumnSpec(label: 'Почта', sortField: 'email', build: (v) => Text(v.email)),
    TableColumnSpec(label: 'Карта', build: (v) => Text(v.card.number)),
    TableColumnSpec(label: 'Тариф', build: (v) => Text(v.card.tariff)),
    TableColumnSpec(
      label: 'Посещений',
      sortField: 'visitsLeft',
      numeric: true,
      build: (v) => Text('${v.card.visitsLeft}'),
    ),
  ],
);
