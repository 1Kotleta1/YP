import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../state/details_notifier.dart';
import '../state/director_list_notifier.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/delete_dialog.dart';
import '../widgets/details_card.dart';
import '../widgets/state_views.dart';

class DirectorDetailsScreen extends StatelessWidget {
  const DirectorDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final details = context.watch<DirectorDetailsNotifier>();
    final list = context.read<DirectorListNotifier>();
    final backTo = listLocation('/directors', list.query);

    Widget body;
    if (details.status == LoadStatus.error) {
      body = ErrorView(message: details.error ?? '', onRetry: details.load);
    } else if (details.status != LoadStatus.success) {
      body = const LoadingView();
    } else if (details.notFound) {
      body = EmptyView(message: 'Режиссёр с номером ${details.id} не найден.');
    } else {
      final director = details.item!.director;
      final movies = details.item!.movies;
      body = DetailsCard(
        title: '${director.firstName} ${director.lastName}',
        deleted: director.isDeleted,
        rows: {
          'Страна': Text(director.country),
          'Год рождения': Text('${director.birthYear}'),
          'Фильмы (${movies.length})': Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in movies)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => context.go('/movies/${m.id}'),
                  child: Text('${m.title} (${m.year})'),
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
          if (director.isDeleted)
            FilledButton.tonalIcon(
              onPressed: () async {
                await list.restore(director.id);
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
                  what: director.fullName, allowSoft: !director.isDeleted);
              if (mode == null) return;
              await list.delete(director.id, permanent: mode == DeleteMode.hard);
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
      section: AppSection.directors,
      title: 'Карточка режиссёра',
      leading: IconButton(
        tooltip: 'К списку',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(backTo),
      ),
      child: body,
    );
  }
}
