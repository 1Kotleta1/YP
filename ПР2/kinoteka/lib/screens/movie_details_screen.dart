import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../repositories/reference_repository.dart';
import '../state/details_notifier.dart';
import '../state/movie_list_notifier.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/delete_dialog.dart';
import '../widgets/details_card.dart';
import '../widgets/state_views.dart';

class MovieDetailsScreen extends StatelessWidget {
  const MovieDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final details = context.watch<MovieDetailsNotifier>();
    final list = context.read<MovieListNotifier>();
    final refs = context.read<ReferenceRepository>();
    final backTo = listLocation('/movies', list.query);

    Widget body;
    if (details.status == LoadStatus.error) {
      body = ErrorView(message: details.error ?? '', onRetry: details.load);
    } else if (details.status != LoadStatus.success) {
      body = const LoadingView();
    } else if (details.notFound) {
      body = EmptyView(message: 'Фильм с номером ${details.id} не найден.');
    } else {
      final movie = details.item!.movie;
      final directors = details.item!.directors;
      body = DetailsCard(
        title: movie.title,
        subtitle: movie.originalTitle == movie.title ? null : movie.originalTitle,
        deleted: movie.isDeleted,
        rows: {
          'Год выпуска': Text('${movie.year}'),
          'Длительность': Text('${movie.duration} мин'),
          'Рейтинг': Text('★ ${movie.rating.toStringAsFixed(1)}'),
          'Киностудия': Text(refs.studioName(movie.studioId)),
          'Жанры': Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in movie.genreIds) Chip(label: Text(refs.genreName(id))),
            ],
          ),
          'Режиссёр': Wrap(
            spacing: 6,
            children: [
              for (final d in directors)
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(d.fullName),
                  onPressed: () => context.go('/directors/${d.id}'),
                ),
            ],
          ),
        },
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go(backTo),
            icon: const Icon(Icons.list),
            label: const Text('К списку'),
          ),
          if (movie.isDeleted)
            FilledButton.tonalIcon(
              onPressed: () async {
                await list.restore(movie.id);
                await details.load();
              },
              icon: const Icon(Icons.restore_from_trash),
              label: const Text('Восстановить'),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              final mode = await confirmDelete(context,
                  what: '«${movie.title}»', allowSoft: !movie.isDeleted);
              if (mode == null) return;
              await list.delete(movie.id, permanent: mode == DeleteMode.hard);
              if (!context.mounted) return;
              mode == DeleteMode.hard ? context.go(backTo) : await details.load();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить'),
          ),
        ],
      );
    }

    return AppShell(
      section: AppSection.movies,
      title: 'Карточка фильма',
      leading: IconButton(
        tooltip: 'К списку',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(backTo),
      ),
      child: body,
    );
  }
}
