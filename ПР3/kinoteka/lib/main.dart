import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/director_query.dart';
import 'models/movie_query.dart';
import 'models/simple_query.dart';
import 'repositories/entity_repository.dart';
import 'repositories/relation_guard.dart';
import 'repositories/repositories.dart';
import 'router.dart';
import 'services/local_store.dart';
import 'services/network_simulator.dart';
import 'services/preferences_service.dart';
import 'state/lookups.dart';
import 'state/paged_list_notifier.dart';
import 'state/startup_notices.dart';
import 'state/theme_controller.dart';
import 'state/unsaved_changes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Хранилище открывается до запуска приложения: сначала миграция формата,
  // затем репозитории читают свои коллекции.
  final prefs = await SharedPreferences.getInstance();
  final store = LocalStore(prefs);
  await store.migrate();

  final network = NetworkSimulator();
  final MovieRepository movies = PersistentMovieRepository(store, network);
  final DirectorRepository directors = PersistentDirectorRepository(store, network);
  final GenreRepository genres = PersistentGenreRepository(store, network);
  final StudioRepository studios = PersistentStudioRepository(store, network);
  final ViewerRepository viewers = PersistentViewerRepository(store, network);
  final guard = RelationGuard(movies);

  final lookups = Lookups(movies, directors, genres, studios);
  await lookups.load();

  final themeController = ThemeController(PreferencesService());
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: network),
        Provider.value(value: UnsavedChanges()),
        Provider<MovieRepository>.value(value: movies),
        Provider<DirectorRepository>.value(value: directors),
        Provider<GenreRepository>.value(value: genres),
        Provider<StudioRepository>.value(value: studios),
        Provider<ViewerRepository>.value(value: viewers),
        ChangeNotifierProvider.value(value: lookups),
        ChangeNotifierProvider(create: (_) => StartupNotices(store.notices)),
        // Списки живут на уровне приложения: при возврате из карточки
        // фильтры, страница и выделение сохраняются
        ChangeNotifierProvider(
          create: (_) => MovieListNotifier(movies, MovieQuery(), onMutated: lookups.load),
        ),
        ChangeNotifierProvider(
          create: (_) => DirectorListNotifier(directors, DirectorQuery(),
              deleteCheck: guard.directors, onMutated: lookups.load),
        ),
        ChangeNotifierProvider(
          create: (_) => GenreListNotifier(genres, SimpleQuery(genreQuerySpec),
              deleteCheck: guard.genres, onMutated: lookups.load),
        ),
        ChangeNotifierProvider(
          create: (_) => StudioListNotifier(studios, SimpleQuery(studioQuerySpec),
              deleteCheck: guard.studios, onMutated: lookups.load),
        ),
        ChangeNotifierProvider(
          create: (_) => ViewerListNotifier(viewers, SimpleQuery(viewerQuerySpec)),
        ),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: KinotekaApp(router: createRouter()),
    ),
  );
}

class KinotekaApp extends StatelessWidget {
  const KinotekaApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeController>().mode;
    return MaterialApp.router(
      title: 'Кинотека',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
