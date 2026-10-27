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
import 'core/server_status.dart';
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

  // Адрес API задаётся только параметром сборки — без него работать не с чем
  if (apiBaseUrl.isEmpty) {
    runApp(const _NoApiAddressApp());
    return;
  }

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
  // Пропала связь — опрашиваем сервер и сообщаем экранам, когда он вернулся
  final serverStatus = ServerStatus(healthPing(), interval: healthCheckInterval);

  final dio = buildDio(
    debugFlags: debugFlags,
    tokenProvider: () => auth.accessToken,
    refreshToken: auth.refreshTokens,
    serverStatus: serverStatus,
  );

  runApp(
    MultiProvider(
      providers: [
        // __delay и __fail из адреса страницы — для проверки состояний экрана
        ChangeNotifierProvider.value(value: debugFlags),
        Provider.value(value: unsaved),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: serverStatus),

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
          create: (c) => Lookups(
            c.read<MovieRepository>(),
            c.read<DirectorRepository>(),
            c.read<GenreRepository>(),
            c.read<StudioRepository>(),
          ),
        ),

        // Списки живут на уровне приложения: при возврате из карточки
        // фильтры, страница и выделение сохраняются
        ChangeNotifierProvider(
          create: (c) => MovieListNotifier(
            c.read<MovieRepository>(),
            MovieQuery(),
            onMutated: () => c.read<Lookups>().invalidate(LookupPart.cascade),
            onLoaded: c.read<Lookups>().ensureLoaded,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => DirectorListNotifier(
            c.read<DirectorRepository>(),
            DirectorQuery(),
            onMutated: () => c.read<Lookups>().invalidate(LookupPart.directors),
            onLoaded: c.read<Lookups>().ensureLoaded,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => GenreListNotifier(
            c.read<GenreRepository>(),
            SimpleQuery(genreQuerySpec),
            onMutated: () => c.read<Lookups>().invalidate(LookupPart.genres),
            onLoaded: c.read<Lookups>().ensureLoaded,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => StudioListNotifier(
            c.read<StudioRepository>(),
            SimpleQuery(studioQuerySpec),
            onMutated: () => c.read<Lookups>().invalidate(LookupPart.studios),
            onLoaded: c.read<Lookups>().ensureLoaded,
          ),
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
/// Когда после обрыва вернулась связь с сервером, перезагружает списки,
/// которые остались с ошибкой.
class _SessionReset extends StatefulWidget {
  const _SessionReset({required this.child});

  final Widget child;

  @override
  State<_SessionReset> createState() => _SessionResetState();
}

class _SessionResetState extends State<_SessionReset> {
  late final AuthNotifier _auth = context.read<AuthNotifier>();
  late final ServerStatus _server = context.read<ServerStatus>();
  int? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.user?.id;
    _auth.addListener(_onAuth);
    _server.addListener(_onServer);
  }

  void _onServer() {
    if (!_server.online || _auth.user == null) return;
    final lists = <PagedListNotifier>[
      context.read<MovieListNotifier>(),
      context.read<DirectorListNotifier>(),
      context.read<GenreListNotifier>(),
      context.read<StudioListNotifier>(),
      context.read<ViewerListNotifier>(),
    ];
    for (final list in lists) {
      if (list.status == LoadStatus.error) list.load();
    }
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
    _server.removeListener(_onServer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: brightness),
  useMaterial3: true,
  // Диалоги не растягиваются на всю ширину большого монитора
  dialogTheme: const DialogThemeData(constraints: BoxConstraints(minWidth: 280, maxWidth: 520)),
);

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
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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

/// Сборка без --dart-define=API_BASE_URL: вместо белого экрана — подсказка.
class _NoApiAddressApp extends StatelessWidget {
  const _NoApiAddressApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Кинотека',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Не задан адрес API.\n'
              'Соберите приложение с параметром --dart-define=API_BASE_URL=…\n'
              'или --dart-define-from-file=env/local.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
