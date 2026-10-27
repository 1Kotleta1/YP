import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../core/api_debug.dart';
import '../core/breakpoints.dart';
import '../core/server_status.dart';
import '../models/list_query.dart';
import '../state/paged_list_notifier.dart';
import '../state/theme_controller.dart';
import '../state/unsaved_changes.dart';

enum AppSection { home, movies, directors, genres, studios, viewers, myCard, boxOffice, users, stats }

/// Раздел навигации: значки, подпись и право, без которого раздел скрыт.
class _Destination {
  const _Destination(this.section, this.icon, this.selectedIcon, this.label, this.permission);

  final AppSection section;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Permission? permission;
}

const _destinations = [
  _Destination(AppSection.home, Icons.home_outlined, Icons.home, 'Главная', null),
  _Destination(AppSection.movies, Icons.movie_outlined, Icons.movie, 'Фильмы', Permission.catalogRead),
  _Destination(AppSection.directors, Icons.people_outline, Icons.people, 'Режиссёры', Permission.catalogRead),
  _Destination(AppSection.genres, Icons.local_offer_outlined, Icons.local_offer, 'Жанры', Permission.catalogRead),
  _Destination(AppSection.studios, Icons.business_outlined, Icons.business, 'Студии', Permission.catalogRead),
  _Destination(AppSection.viewers, Icons.badge_outlined, Icons.badge, 'Зрители', Permission.viewersManage),
  _Destination(AppSection.myCard, Icons.credit_card_outlined, Icons.credit_card, 'Моя карта', Permission.cardOwn),
  _Destination(AppSection.boxOffice, Icons.point_of_sale_outlined, Icons.point_of_sale, 'Касса', Permission.visitsMark),
  _Destination(
    AppSection.users,
    Icons.manage_accounts_outlined,
    Icons.manage_accounts,
    'Пользователи',
    Permission.usersManage,
  ),
  _Destination(AppSection.stats, Icons.insights_outlined, Icons.insights, 'Статистика', Permission.statsView),
];

/// Разделы, доступные роли, — в том порядке, в каком они показываются.
List<AppSection> sectionsFor(Role? role) => [
  for (final d in _destinations)
    if (d.permission == null || roleCan(role, d.permission!)) d.section,
];

String sectionLabel(AppSection s) => _destinations.firstWhere((d) => d.section == s).label;

/// Каркас всех экранов: заголовок, разделы по роли пользователя, тема,
/// меню пользователя и меню «Проверка» со служебными параметрами сервера.
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

  /// null — экран вне разделов (например, отказ в доступе).
  final AppSection? section;
  final String title;
  final Widget child;
  final VoidCallback? onReload;
  final Widget? leading;
  final VoidCallback? onAdd;
  final String? addLabel;

  /// Возврат в раздел восстанавливает его последние условия отбора.
  static void goTo(BuildContext context, AppSection section) {
    context.go(switch (section) {
      AppSection.home => '/',
      AppSection.movies => listLocation('/movies', context.read<MovieListNotifier>().query),
      AppSection.directors => listLocation('/directors', context.read<DirectorListNotifier>().query),
      AppSection.genres => listLocation('/genres', context.read<GenreListNotifier>().query),
      AppSection.studios => listLocation('/studios', context.read<StudioListNotifier>().query),
      AppSection.viewers => listLocation('/viewers', context.read<ViewerListNotifier>().query),
      AppSection.myCard => '/my-card',
      AppSection.boxOffice => '/box-office',
      AppSection.users => '/admin/users',
      AppSection.stats => '/admin/stats',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final flags = context.watch<ApiDebugFlags>();
    final auth = context.watch<AuthNotifier>();
    final isDark = theme.mode == ThemeMode.dark;
    final server = context.watch<ServerStatus>();
    // Телефон — навигация снизу; планшет — полоса значков с подписями;
    // от 1024 px — развёрнутая навигация; от 1600 px — содержимое по центру
    final size = context.windowSize;
    final wide = size >= WindowSize.medium;
    final extended = size >= WindowSize.expanded;
    final visible = [
      for (final d in _destinations)
        if (sectionsFor(auth.role).contains(d.section)) d,
    ];
    final index = visible.indexWhere((d) => d.section == section);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!server.online)
          MaterialBanner(
            leading: const Icon(Icons.cloud_off_outlined),
            content: const Text(
              'Нет связи с сервером. Проверяем каждые несколько секунд — '
              'когда связь вернётся, данные загрузятся сами.',
            ),
            actions: [TextButton(onPressed: server.check, child: const Text('Проверить сейчас'))],
          ),
        if (flags.delayMs != null || flags.failAlways != null)
          MaterialBanner(
            leading: const Icon(Icons.science_outlined),
            content: Text(
              [
                if (flags.delayMs != null) 'Каждый запрос задерживается на ${flags.delayMs} мс (__delay).',
                if (flags.failAlways != null) 'Каждый запрос получает ответ ${flags.failAlways} (__fail).',
              ].join('\n'),
            ),
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
        Expanded(
          child: size == WindowSize.large
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                    child: child,
                  ),
                )
              : child,
        ),
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
                  : IconButton.filled(tooltip: addLabel ?? 'Добавить', onPressed: onAdd, icon: const Icon(Icons.add)),
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
          if (auth.user != null) _UserMenu(auth: auth, wide: wide),
        ],
      ),
      body: wide
          ? Row(
              children: [
                _ScrollableRail(
                  extended: extended,
                  selectedIndex: index < 0 ? null : index,
                  destinations: visible,
                  onSelected: (i) => goTo(context, visible[i].section),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide ? null : _BottomBar(visible: visible, index: index),
    );
  }
}

/// Боковая навигация прокручивается, если разделов больше, чем помещается.
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.extended,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final bool extended;
  final int? selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              extended: extended,
              minExtendedWidth: 200,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              onDestinationSelected: onSelected,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// На узком окне внизу помещается не больше пяти разделов: первые четыре
/// показываются сразу, остальные — в списке «Ещё».
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.visible, required this.index});

  final List<_Destination> visible;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fits = visible.length <= 5;
    final shown = fits ? visible : visible.take(4).toList();
    final rest = fits ? const <_Destination>[] : visible.skip(4).toList();
    final selected = index < 0 ? null : (index < shown.length ? index : shown.length);
    return NavigationBar(
      selectedIndex: selected ?? 0,
      indicatorColor: selected == null ? Colors.transparent : null,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) async {
        if (i < shown.length) return AppShell.goTo(context, shown[i].section);
        final section = await showModalBottomSheet<AppSection>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in rest)
                  ListTile(leading: Icon(d.icon), title: Text(d.label), onTap: () => Navigator.pop(context, d.section)),
              ],
            ),
          ),
        );
        if (section != null && context.mounted) AppShell.goTo(context, section);
      },
      destinations: [
        for (final d in shown)
          NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        if (rest.isNotEmpty) const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Ещё'),
      ],
    );
  }
}

/// Имя пользователя и роль в шапке, выход из системы.
class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.auth, required this.wide});

  final AuthNotifier auth;
  final bool wide;

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final user = auth.user!;
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: 15,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        user.displayName.characters.first.toUpperCase(),
        style: TextStyle(fontSize: 14, color: scheme.onPrimaryContainer),
      ),
    );
    return PopupMenuButton<String>(
      tooltip: 'Пользователь',
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v != 'logout') return;
        // Выход не должен застревать на вопросе о несохранённой форме
        context.read<UnsavedChanges>().dirty = false;
        auth.logout();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: avatar,
            title: Text(user.displayName),
            subtitle: Text('${user.username} · ${user.role.title}'),
          ),
        ),
        if (auth.sessionEndsAt != null)
          PopupMenuItem(
            enabled: false,
            child: Text(
              'Сессия действует до ${_time(auth.sessionEndsAt!)}'
              '${auth.refreshCount > 0 ? '\nТокен обновлялся: ${auth.refreshCount}' : ''}',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout), title: Text('Выйти')),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            if (wide) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: Theme.of(context).textTheme.labelLarge),
                  Text(user.role.title, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ],
        ),
      ),
    );
  }
}
