import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../services/network_simulator.dart';
import '../state/director_list_notifier.dart';
import '../state/movie_list_notifier.dart';
import '../state/theme_controller.dart';
import 'entity_list_view.dart';

enum AppSection { movies, directors }

/// Каркас всех экранов: заголовок, переключение разделов, тема
/// и имитация сбоя сети для проверки экрана ошибки.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.section,
    required this.title,
    required this.child,
    this.onReload,
    this.leading,
  });

  final AppSection section;
  final String title;
  final Widget child;
  final VoidCallback? onReload;
  final Widget? leading;

  /// Возврат в раздел восстанавливает его последние условия отбора.
  void _goTo(BuildContext context, int index) {
    context.go(index == 0
        ? listLocation('/movies', context.read<MovieListNotifier>().query)
        : listLocation('/directors', context.read<DirectorListNotifier>().query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final isDark = theme.mode == ThemeMode.dark;
    final wide = MediaQuery.sizeOf(context).width >= tableBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: [
          if (onReload != null)
            PopupMenuButton<String>(
              tooltip: 'Проверка',
              icon: const Icon(Icons.bug_report_outlined),
              onSelected: (_) {
                context.read<NetworkSimulator>().failNext();
                onReload!();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'fail', child: Text('Имитировать сбой загрузки')),
              ],
            ),
          IconButton(
            tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
            onPressed: theme.toggleLightDark,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: section.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => _goTo(context, i),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.movie_outlined),
                      selectedIcon: Icon(Icons.movie),
                      label: Text('Фильмы'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Режиссёры'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section.index,
              onDestinationSelected: (i) => _goTo(context, i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Фильмы'),
                NavigationDestination(icon: Icon(Icons.people_outline), label: 'Режиссёры'),
              ],
            ),
    );
  }
}
