import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/movie.dart';
import '../models/list_query.dart';
import '../models/movie_query.dart';
import '../state/lookups.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_panel.dart';

/// Список фильмов. Условия отбора приходят из адреса — так ссылку
/// на отфильтрованный список можно открыть в новой вкладке.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key, required this.query});

  final MovieQuery query;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  @override
  void initState() {
    super.initState();
    _applyFromUrl();
  }

  @override
  void didUpdateWidget(covariant MovieListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _applyFromUrl();
  }

  void _applyFromUrl() {
    final query = widget.query;
    // Состояние меняем после кадра: во время build уведомлять слушателей нельзя
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MovieListNotifier>().applyQuery(query);
    });
  }

  void _navigate(MovieQuery next) => context.go(listLocation('/movies', next));

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MovieListNotifier>();
    final refs = context.watch<Lookups>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    String genres(Movie m) => m.genreIds.map(refs.genreName).join(', ');

    return AppShell(
      section: AppSection.movies,
      title: 'Кинотека — фильмы',
      onReload: notifier.load,
      onAdd: auth.can(Permission.catalogEdit) ? () => context.go('/movies/new') : null,
      addLabel: 'Новый фильм',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterPanel(
            activeCount: [
              q.search.isNotEmpty,
              q.genreId != null,
              q.studioId != null,
              q.yearFrom != null || q.yearTo != null,
            ].where((x) => x).length,
            children: [
              DebouncedTextField(
                width: 280,
                label: 'Поиск по названию или № ПУ',
                icon: Icons.search,
                value: q.search,
                onChanged: (v) => _navigate(q.copyWith(search: v)),
              ),
              FilterDropdown<int>(
                label: 'Жанр',
                allLabel: 'Все жанры',
                value: q.genreId,
                options: {for (final g in refs.genres) g.id: g.name},
                onChanged: (v) => _navigate(q.copyWith(genreId: v)),
                width: 180,
              ),
              FilterDropdown<int>(
                label: 'Киностудия',
                allLabel: 'Все студии',
                value: q.studioId,
                options: {for (final s in refs.studios) s.id: s.name},
                onChanged: (v) => _navigate(q.copyWith(studioId: v)),
              ),
              DebouncedTextField(
                width: 120,
                label: 'Год с',
                digitsOnly: true,
                value: q.yearFrom?.toString() ?? '',
                onChanged: (v) => _navigate(q.copyWith(yearFrom: int.tryParse(v))),
              ),
              DebouncedTextField(
                width: 120,
                label: 'Год по',
                digitsOnly: true,
                value: q.yearTo?.toString() ?? '',
                onChanged: (v) => _navigate(q.copyWith(yearTo: int.tryParse(v))),
              ),
              if (auth.can(Permission.trashView))
                FilterChip(
                  label: const Text('Показывать удалённые'),
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
            child: EntityListView<Movie, MovieQuery>(
              notifier: notifier,
              onNavigate: _navigate,
              onOpen: (m) => context.go('/movies/${m.id}'),
              onEdit: (m) => context.go('/movies/${m.id}/edit'),
              isDeleted: (m) => m.isDeleted,
              describe: (m) => m.title,
              cardTitle: (m) => Text('${m.title} (${m.year})'),
              cardSubtitle: (m) => Text(
                '${refs.studioName(m.studioId)} · ${m.duration} мин · ★ ${m.rating.toStringAsFixed(1)}\n${genres(m)}',
              ),
              columns: [
                TableColumnSpec(
                  label: 'Название',
                  sortField: 'title',
                  build: (m) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: m.isDeleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (m.originalTitle != m.title)
                        Text(m.originalTitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                TableColumnSpec(label: 'Год', sortField: 'year', numeric: true, build: (m) => Text('${m.year}')),
                TableColumnSpec(
                  label: 'Мин',
                  sortField: 'duration',
                  numeric: true,
                  build: (m) => Text('${m.duration}'),
                ),
                TableColumnSpec(
                  label: 'Рейтинг',
                  sortField: 'rating',
                  numeric: true,
                  build: (m) => Text(m.rating.toStringAsFixed(1)),
                ),
                TableColumnSpec(label: 'Жанры', build: (m) => Text(genres(m))),
                TableColumnSpec(label: 'Киностудия', build: (m) => Text(refs.studioName(m.studioId))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
