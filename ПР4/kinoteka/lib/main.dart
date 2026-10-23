import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/api_debug.dart';
import 'models/director_query.dart';
import 'models/movie_query.dart';
import 'models/simple_query.dart';
import 'repositories/api_repositories.dart';
import 'repositories/entity_repository.dart';
import 'router.dart';
import 'services/preferences_service.dart';
import 'state/lookups.dart';
import 'state/paged_list_notifier.dart';
import 'state/theme_controller.dart';
import 'state/unsaved_changes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final themeController = ThemeController(PreferencesService());
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        // __delay и __fail из адреса страницы — для проверки состояний экрана
        ChangeNotifierProvider(create: (_) => ApiDebugFlags.fromPageUrl(Uri.base)),
        Provider(create: (_) => UnsavedChanges()),

        // Единственное место, где приложение переключилось на сервер:
        // было — Persistent*Repository поверх localStorage,
        // стало — Api*Repository поверх Dio.
        Provider<Dio>(create: (c) => buildDio(debugFlags: c.read<ApiDebugFlags>())),
        ProxyProvider<Dio, MovieRepository>(update: (_, dio, prev) => prev ?? ApiMovieRepository(dio)),
        ProxyProvider<Dio, DirectorRepository>(update: (_, dio, prev) => prev ?? ApiDirectorRepository(dio)),
        ProxyProvider<Dio, GenreRepository>(update: (_, dio, prev) => prev ?? ApiGenreRepository(dio)),
        ProxyProvider<Dio, StudioRepository>(update: (_, dio, prev) => prev ?? ApiStudioRepository(dio)),
        ProxyProvider<Dio, ViewerRepository>(update: (_, dio, prev) => prev ?? ApiViewerRepository(dio)),

        // Справочники не блокируют запуск: если сервер недоступен,
        // приложение откроется и покажет ошибку с кнопкой повтора
        ChangeNotifierProvider(
          create: (c) => Lookups(c.read<MovieRepository>(), c.read<DirectorRepository>(),
              c.read<GenreRepository>(), c.read<StudioRepository>())
            ..ensureLoaded(),
        ),

        // Списки живут на уровне приложения: при возврате из карточки
        // фильтры, страница и выделение сохраняются
        ChangeNotifierProvider(
          create: (c) => MovieListNotifier(c.read<MovieRepository>(), MovieQuery(),
              onMutated: () => c.read<Lookups>().invalidate(LookupPart.cascade),
              onLoaded: c.read<Lookups>().ensureLoaded),
        ),
        ChangeNotifierProvider(
          create: (c) => DirectorListNotifier(c.read<DirectorRepository>(), DirectorQuery(),
              onMutated: () => c.read<Lookups>().invalidate(LookupPart.directors),
              onLoaded: c.read<Lookups>().ensureLoaded),
        ),
        ChangeNotifierProvider(
          create: (c) => GenreListNotifier(c.read<GenreRepository>(), SimpleQuery(genreQuerySpec),
              onMutated: () => c.read<Lookups>().invalidate(LookupPart.genres),
              onLoaded: c.read<Lookups>().ensureLoaded),
        ),
        ChangeNotifierProvider(
          create: (c) => StudioListNotifier(c.read<StudioRepository>(), SimpleQuery(studioQuerySpec),
              onMutated: () => c.read<Lookups>().invalidate(LookupPart.studios),
              onLoaded: c.read<Lookups>().ensureLoaded),
        ),
        ChangeNotifierProvider(
          create: (c) => ViewerListNotifier(c.read<ViewerRepository>(), SimpleQuery(viewerQuerySpec)),
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
