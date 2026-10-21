import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../services/network_simulator.dart';
import '../state/paged_list_notifier.dart';
import '../state/startup_notices.dart';
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

/// Каркас всех экранов: заголовок, переключение разделов, тема,
/// сообщения о миграции данных и имитация сбоя сети.
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
    final notices = context.watch<StartupNotices>();
    final isDark = theme.mode == ThemeMode.dark;
    final wide = MediaQuery.sizeOf(context).width >= tableBreakpoint;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notices.messages.isNotEmpty)
          MaterialBanner(
            leading: const Icon(Icons.update),
            content: Text(notices.messages.join('\n')),
            actions: [TextButton(onPressed: notices.dismiss, child: const Text('Понятно'))],
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
