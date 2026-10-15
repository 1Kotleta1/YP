import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'repositories/director_repository.dart';
import 'repositories/in_memory_director_repository.dart';
import 'repositories/in_memory_movie_repository.dart';
import 'repositories/movie_repository.dart';
import 'repositories/reference_repository.dart';
import 'router.dart';
import 'services/network_simulator.dart';
import 'services/preferences_service.dart';
import 'state/director_list_notifier.dart';
import 'state/movie_list_notifier.dart';
import 'state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final themeController = ThemeController(PreferencesService());
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => NetworkSimulator()),
        Provider(create: (_) => const ReferenceRepository()),
        Provider<MovieRepository>(
          create: (context) => InMemoryMovieRepository(context.read<NetworkSimulator>()),
        ),
        Provider<DirectorRepository>(
          create: (context) => InMemoryDirectorRepository(context.read<NetworkSimulator>()),
        ),
        // Списки живут на уровне приложения: при возврате из карточки
        // фильтры, страница и выделение сохраняются
        ChangeNotifierProvider(
          create: (context) => MovieListNotifier(context.read<MovieRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => DirectorListNotifier(context.read<DirectorRepository>()),
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
