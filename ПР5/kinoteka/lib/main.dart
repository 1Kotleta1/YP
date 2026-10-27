import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_api.dart';
import 'auth/auth_notifier.dart';
import 'auth/inactivity_watcher.dart';
import 'core/api_client.dart';
import 'core/api_debug.dart';
import 'core/config.dart';
import 'models/director_query.dart';
import 'models/movie_query.dart';
import 'models/simple_query.dart';
import 'repositories/account_repositories.dart';
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

  // Сессия восстанавливается до построения дерева виджетов: иначе после
  // перезагрузки страницы маршрутизатор успел бы отправить на экран входа
  final auth = AuthNotifier(await SharedPreferences.getInstance(), AuthApi(buildDio()));
  await auth.restore();

  final debugFlags = ApiDebugFlags.fromPageUrl(Uri.base);
  final unsaved = UnsavedChanges();

  // Каждый запрос к API уходит с заголовком Authorization; на 401
  // токен обновляется, и запрос повторяется
  final dio = buildDio(
    debugFlags: debugFlags,
    tokenProvider: () => auth.accessToken,
    refreshToken: auth.refreshTokens,
  );

  runApp(
    MultiProvider(
      providers: [
        // __delay и __fail из адреса страницы — для проверки состояний экрана
        ChangeNotifierProvider.value(value: debugFlags),
        Provider.value(value: unsaved),
        ChangeNotifierProvider.value(value: auth),

        Provider<Dio>.value(value: dio),
        Provider<MovieRepository>(create: (_) => ApiMovieRepository(dio)),
        Provider<DirectorRepository>(create: (_) => ApiDirectorRepository(dio)),
        Provider<GenreRepository>(create: (_) => ApiGenreRepository(dio)),
        Provider<StudioRepository>(create: (_) => ApiStudioRepository(dio)),
        Provider<ViewerRepository>(create: (_) => ApiViewerRepository(dio)),
        Provider(create: (_) => AccountRepository(dio)),

        // Справочники загружаются при первом открытии списка или формы:
        // до входа в систему сервер всё равно ответил бы 401
        ChangeNotifierProvider(
          create: (c) => Lookups(c.read<MovieRepository>(), c.read<DirectorRepository>(),
              c.read<GenreRepository>(), c.read<StudioRepository>()),
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
      child: _SessionReset(child: KinotekaApp(router: createRouter(auth))),
    ),
  );
}

/// При выходе из системы очищает списки, справочники и признак
/// несохранённой формы: следующий пользователь начинает с чистого листа.
class _SessionReset extends StatefulWidget {
  const _SessionReset({required this.child});

  final Widget child;

  @override
  State<_SessionReset> createState() => _SessionResetState();
}

class _SessionResetState extends State<_SessionReset> {
  late final AuthNotifier _auth = context.read<AuthNotifier>();
  int? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.user?.id;
    _auth.addListener(_onAuth);
  }

  void _onAuth() {
    final id = _auth.user?.id;
    if (id == _userId) return;
    _userId = id;
    context.read<UnsavedChanges>().dirty = false;
    context.read<Lookups>().reset();
    context.read<MovieListNotifier>().reset(MovieQuery());
    context.read<DirectorListNotifier>().reset(DirectorQuery());
    context.read<GenreListNotifier>().reset(SimpleQuery(genreQuerySpec));
    context.read<StudioListNotifier>().reset(SimpleQuery(studioQuerySpec));
    context.read<ViewerListNotifier>().reset(SimpleQuery(viewerQuerySpec));
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
      // Таймер неактивности охватывает всё приложение
      builder: (context, child) => InactivityWatcher(
        auth: context.read<AuthNotifier>(),
        timeout: inactivityTimeout,
        warning: inactivityWarning,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
