import 'package:go_router/go_router.dart';

import 'screens/calculator_screen.dart';
import 'screens/converter_screen.dart';
import 'screens/home_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/result_screen.dart';
import 'services/preferences_service.dart';
import 'theme_controller.dart';

GoRouter createAppRouter({
  required ThemeController themeController,
  required PreferencesService prefs,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            HomeScreen(themeController: themeController),
      ),
      GoRoute(
        path: '/calculator',
        builder: (context, state) =>
            CalculatorScreen(themeController: themeController),
        routes: [
          GoRoute(
            path: 'result',
            builder: (context, state) {
              return ResultScreen(
                kind: ResultKind.calculator,
                backPath: '/calculator',
                query: state.uri.queryParameters,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/converter',
        builder: (context, state) => ConverterScreen(
          themeController: themeController,
          prefs: prefs,
        ),
        routes: [
          GoRoute(
            path: 'result',
            builder: (context, state) {
              return ResultScreen(
                kind: ResultKind.converter,
                backPath: '/converter',
                query: state.uri.queryParameters,
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}
