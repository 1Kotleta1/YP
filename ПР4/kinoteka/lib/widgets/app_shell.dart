import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_debug.dart';
import '../models/list_query.dart';
import '../state/paged_list_notifier.dart';
import '../state/theme_controller.dart';
import 'entity_list_view.dart';

enum AppSection { movies, directors, genres, studios, viewers }

const _sections = [
  (Icons.movie_outlined, Icons.movie, 'Фильмы'),
  (Icons.people_outline, Icons.people, 'Режиссёры'),
  (Icons.local_offer_outlined, Icons.local_offer, 'Жанры'),
  (Icons.business_outlined, Icons.business, 'Студии'),
  (Icons.badge_outlined, Icons.badge, 'Зрители'),
];

/// Каркас всех экранов: заголовок, переключение разделов, тема
/// и меню «Проверка» со служебными параметрами учебного сервера.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.section,
    required this.title,
    required this.child,
    this.onReload,
    this.leading,
    this.onAdd,
    this.addLabel,
  });

  final AppSection section;
  final String title;
  final Widget child;
  final VoidCallback? onReload;
  final Widget? leading;
  final VoidCallback? onAdd;
  final String? addLabel;

  /// Возврат в раздел восстанавливает его последние условия отбора.
  void _goTo(BuildContext context, int index) {
    context.go(switch (AppSection.values[index]) {
      AppSection.movies => listLocation('/movies', context.read<MovieListNotifier>().query),
      AppSection.directors =>
        listLocation('/directors', context.read<DirectorListNotifier>().query),
      AppSection.genres => listLocation('/genres', context.read<GenreListNotifier>().query),
      AppSection.studios => listLocation('/studios', context.read<StudioListNotifier>().query),
      AppSection.viewers => listLocation('/viewers', context.read<ViewerListNotifier>().query),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final flags = context.watch<ApiDebugFlags>();
    final isDark = theme.mode == ThemeMode.dark;
    final wide = MediaQuery.sizeOf(context).width >= tableBreakpoint;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flags.delayMs != null || flags.failAlways != null)
          MaterialBanner(
            leading: const Icon(Icons.science_outlined),
            content: Text([
              if (flags.delayMs != null) 'Каждый запрос задерживается на ${flags.delayMs} мс (__delay).',
              if (flags.failAlways != null) 'Каждый запрос получает ответ ${flags.failAlways} (__fail).',
            ].join('\n')),
            actions: [
              TextButton(
                onPressed: () {
                  flags.delayMs = null;
                  flags.clearFailAlways();
                  onReload?.call();
                },
                child: const Text('Отключить'),
              ),
            ],
          ),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: [
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: wide
                  ? FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(addLabel ?? 'Добавить'),
                    )
                  : IconButton.filled(
                      tooltip: addLabel ?? 'Добавить',
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                    ),
            ),
          if (onReload != null)
            PopupMenuButton<String>(
              tooltip: 'Проверка',
              icon: const Icon(Icons.bug_report_outlined),
              onSelected: (action) {
                switch (action) {
                  case 'fail':
                    flags.failNext(500);
                  case 'delay':
                    flags.delayMs = flags.delayMs == null ? 1500 : null;
                }
                onReload!();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'fail', child: Text('Ответ 500 на следующий запрос (__fail=500)')),
                CheckedPopupMenuItem(
                  value: 'delay',
                  checked: flags.delayMs != null,
                  child: const Text('Задержка 1500 мс (__delay=1500)'),
                ),
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
                  destinations: [
                    for (final (icon, selected, label) in _sections)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section.index,
              onDestinationSelected: (i) => _goTo(context, i),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final (icon, selected, label) in _sections)
                  NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
              ],
            ),
    );
  }
}
