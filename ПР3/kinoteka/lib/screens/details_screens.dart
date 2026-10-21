import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/director.dart';
import '../models/director_query.dart';
import '../models/entity.dart';
import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/simple_query.dart';
import '../models/studio.dart';
import '../models/viewer.dart';
import '../repositories/relation_guard.dart';
import '../state/details_notifier.dart';
import '../state/lookups.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/delete_dialog.dart';
import '../widgets/details_card.dart';
import '../widgets/state_views.dart';

/// Общая обвязка карточки: состояния загрузки и кнопка «назад».
class DetailsFrame<T> extends StatelessWidget {
  const DetailsFrame({
    super.key,
    required this.section,
    required this.title,
    required this.backTo,
    required this.builder,
  });

  final AppSection section;
  final String title;
  final String backTo;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DetailsNotifier<T>>();
    final Widget body;
    if (d.status == LoadStatus.error) {
      body = ErrorView(message: d.error ?? '', onRetry: d.load);
    } else if (d.status != LoadStatus.success) {
      body = const LoadingView();
    } else if (d.notFound) {
      body = EmptyView(message: 'Запись с номером ${d.id} не найдена.');
    } else {
      body = builder(context, d.item as T);
    }
    return AppShell(
      section: section,
      title: title,
      leading: IconButton(
        tooltip: 'К списку',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(backTo),
      ),
      child: body,
    );
  }
}

/// Кнопки карточки: к списку, изменить, восстановить, удалить.
List<Widget> detailActions<E extends Entity, Q extends ListQuery>(
  BuildContext context, {
  required E entity,
  required String path,
  required String describe,
  required VoidCallback reload,
}) {
  final list = context.read<PagedListNotifier<E, Q>>();
  final backTo = listLocation(path, list.query);
  final scheme = Theme.of(context).colorScheme;
  return [
    OutlinedButton.icon(
      onPressed: () => context.go(backTo),
      icon: const Icon(Icons.list),
      label: const Text('К списку'),
    ),
    if (!entity.isDeleted)
      FilledButton.tonalIcon(
        onPressed: () => context.go('$path/${entity.id}/edit'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Изменить'),
      ),
    if (entity.isDeleted)
      FilledButton.tonalIcon(
        onPressed: () async {
          await list.restore(entity.id);
          reload();
        },
        icon: const Icon(Icons.restore_from_trash),
        label: const Text('Восстановить'),
      ),
    FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
      onPressed: () async {
        final mode = await confirmDelete(context, what: '«$describe»', allowSoft: !entity.isDeleted);
        if (mode == null) return;
        try {
          await list.delete(entity.id, permanent: mode == DeleteMode.hard);
        } on DeleteBlockedException catch (e) {
          if (context.mounted) await showDeleteBlocked(context, e.message);
          return;
        }
        if (!context.mounted) return;
        mode == DeleteMode.hard ? context.go(backTo) : reload();
      },
      icon: const Icon(Icons.delete_outline),
      label: const Text('Удалить'),
    ),
  ];
}

Widget _movieLinks(BuildContext context, List<Movie> movies) => movies.isEmpty
    ? const Text('—')
    : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in movies)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => context.go('/movies/${m.id}'),
              child: Text('${m.title} (${m.year})'),
            ),
        ],
      );

class MovieDetailsScreen extends StatelessWidget {
  const MovieDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<Lookups>();
    final reload = context.read<DetailsNotifier<MovieDetails>>().load;
    return DetailsFrame<MovieDetails>(
      section: AppSection.movies,
      title: 'Карточка фильма',
      backTo: listLocation('/movies', context.read<MovieListNotifier>().query),
      builder: (context, d) {
        final m = d.movie;
        return DetailsCard(
          title: m.title,
          subtitle: m.originalTitle == m.title ? null : m.originalTitle,
          deleted: m.isDeleted,
          rows: {
            'Год выпуска': Text('${m.year}'),
            'Длительность': Text('${m.duration} мин'),
            'Рейтинг': Text('★ ${m.rating.toStringAsFixed(1)}'),
            'Прокатное уд.': Text('№ ${m.licenseNumber}'),
            'Киностудия': ActionChip(
              avatar: const Icon(Icons.business_outlined, size: 18),
              label: Text(refs.studioName(m.studioId)),
              onPressed: () => context.go('/studios/${m.studioId}'),
            ),
            'Жанры': Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in m.genreIds)
                ActionChip(label: Text(refs.genreName(id)), onPressed: () => context.go('/genres/$id')),
            ]),
            'Режиссёр': Wrap(spacing: 6, runSpacing: 6, children: [
              for (final dir in d.directors)
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(dir.fullName),
                  onPressed: () => context.go('/directors/${dir.id}'),
                ),
            ]),
          },
          actions: detailActions<Movie, MovieQuery>(context,
              entity: m, path: '/movies', describe: m.title, reload: reload),
        );
      },
    );
  }
}

class DirectorDetailsScreen extends StatelessWidget {
  const DirectorDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reload = context.read<DetailsNotifier<WithMovies<Director>>>().load;
    return DetailsFrame<WithMovies<Director>>(
      section: AppSection.directors,
      title: 'Карточка режиссёра',
      backTo: listLocation('/directors', context.read<DirectorListNotifier>().query),
      builder: (context, d) => DetailsCard(
        title: '${d.item.firstName} ${d.item.lastName}',
        deleted: d.item.isDeleted,
        rows: {
          'Страна': Text(d.item.country),
          'Год рождения': Text('${d.item.birthYear}'),
          'Фильмы (${d.movies.length})': _movieLinks(context, d.movies),
        },
        actions: detailActions<Director, DirectorQuery>(context,
            entity: d.item, path: '/directors', describe: d.item.fullName, reload: reload),
      ),
    );
  }
}

class GenreDetailsScreen extends StatelessWidget {
  const GenreDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reload = context.read<DetailsNotifier<WithMovies<Genre>>>().load;
    return DetailsFrame<WithMovies<Genre>>(
      section: AppSection.genres,
      title: 'Карточка жанра',
      backTo: listLocation('/genres', context.read<GenreListNotifier>().query),
      builder: (context, d) => DetailsCard(
        title: d.item.name,
        deleted: d.item.isDeleted,
        rows: {
          'Категория': Text(d.item.category),
          'Описание': Text(d.item.description.isEmpty ? '—' : d.item.description),
          'Фильмы (${d.movies.length})': _movieLinks(context, d.movies),
        },
        actions: detailActions<Genre, SimpleQuery>(context,
            entity: d.item, path: '/genres', describe: d.item.name, reload: reload),
      ),
    );
  }
}

class StudioDetailsScreen extends StatelessWidget {
  const StudioDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reload = context.read<DetailsNotifier<WithMovies<Studio>>>().load;
    return DetailsFrame<WithMovies<Studio>>(
      section: AppSection.studios,
      title: 'Карточка киностудии',
      backTo: listLocation('/studios', context.read<StudioListNotifier>().query),
      builder: (context, d) => DetailsCard(
        title: d.item.name,
        deleted: d.item.isDeleted,
        rows: {
          'Страна': Text(d.item.country),
          'Год основания': Text('${d.item.foundedYear}'),
          'Фильмы (${d.movies.length})': _movieLinks(context, d.movies),
        },
        actions: detailActions<Studio, SimpleQuery>(context,
            entity: d.item, path: '/studios', describe: d.item.name, reload: reload),
      ),
    );
  }
}

class ViewerDetailsScreen extends StatelessWidget {
  const ViewerDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reload = context.read<DetailsNotifier<Viewer>>().load;
    return DetailsFrame<Viewer>(
      section: AppSection.viewers,
      title: 'Карточка зрителя',
      backTo: listLocation('/viewers', context.read<ViewerListNotifier>().query),
      builder: (context, v) => DetailsCard(
        title: v.fullName,
        subtitle: v.email,
        deleted: v.isDeleted,
        rows: {
          'Телефон': Text(v.phone.isEmpty ? '—' : v.phone),
          'Карта зрителя': Text(v.card.number),
          'Тариф': Text(v.card.tariff),
          'Посещений': Text('${v.card.visitsLeft}'),
          'Выдана': Text(v.card.issuedAt),
        },
        actions: detailActions<Viewer, SimpleQuery>(context,
            entity: v, path: '/viewers', describe: v.fullName, reload: reload),
      ),
    );
  }
}
