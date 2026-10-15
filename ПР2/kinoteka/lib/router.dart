import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/director_query.dart';
import 'models/movie_query.dart';
import 'repositories/director_repository.dart';
import 'repositories/movie_repository.dart';
import 'screens/director_details_screen.dart';
import 'screens/director_list_screen.dart';
import 'screens/movie_details_screen.dart';
import 'screens/movie_list_screen.dart';
import 'screens/not_found_screen.dart';
import 'state/details_notifier.dart';

/// Страница без анимации: смена условий отбора — это тот же экран,
/// и ключ pageKey не меняется, поэтому поле поиска не теряет фокус.
Page<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage(key: state.pageKey, child: child);

/// Номер записи из адреса; нечисловой номер ведёт на экран 404.
Page<void> _details(GoRouterState state, Widget Function(int id) build) {
  final id = int.tryParse(state.pathParameters['id'] ?? '');
  return _page(
    state,
    id == null ? NotFoundScreen(location: state.uri.toString()) : build(id),
  );
}

// Карточки — маршруты верхнего уровня, а не вложенные в список:
// иначе под карточкой строился бы список с пустыми параметрами адреса
// и сбрасывал бы условия отбора.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/movies',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/movies'),
      GoRoute(
        path: '/movies',
        pageBuilder: (context, state) => _page(
          state,
          MovieListScreen(
            query: MovieQuery.fromQueryParameters(state.uri.queryParameters),
          ),
        ),
      ),
      GoRoute(
        path: '/movies/:id',
        pageBuilder: (context, state) => _details(
          state,
          (id) => ChangeNotifierProvider(
            create: (context) => MovieDetailsNotifier(
              context.read<MovieRepository>(),
              context.read<DirectorRepository>(),
              id,
            )..load(),
            child: const MovieDetailsScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/directors',
        pageBuilder: (context, state) => _page(
          state,
          DirectorListScreen(
            query: DirectorQuery.fromQueryParameters(state.uri.queryParameters),
          ),
        ),
      ),
      GoRoute(
        path: '/directors/:id',
        pageBuilder: (context, state) => _details(
          state,
          (id) => ChangeNotifierProvider(
            create: (context) => DirectorDetailsNotifier(
              context.read<DirectorRepository>(),
              context.read<MovieRepository>(),
              id,
            )..load(),
            child: const DirectorDetailsScreen(),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri.toString()),
  );
}
