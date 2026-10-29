import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../widgets/app_shell.dart';

const _descriptions = {
  AppSection.movies: 'Каталог фильмов: поиск, фильтры, карточки',
  AppSection.directors: 'Режиссёры и их фильмы',
  AppSection.genres: 'Справочник жанров',
  AppSection.studios: 'Справочник киностудий',
  AppSection.viewers: 'Зрители и карты: создание, изменение, корзина',
  AppSection.myCard: 'Моя карта зрителя, история посещений, продление',
  AppSection.boxOffice: 'Поиск карты и отметка посещения',
  AppSection.users: 'Учётные записи, роли и блокировка',
  AppSection.stats: 'Сводка по каталогу, посещениям и пользователям',
};

const _icons = {
  AppSection.movies: Icons.movie_outlined,
  AppSection.directors: Icons.people_outline,
  AppSection.genres: Icons.local_offer_outlined,
  AppSection.studios: Icons.business_outlined,
  AppSection.viewers: Icons.badge_outlined,
  AppSection.myCard: Icons.credit_card_outlined,
  AppSection.boxOffice: Icons.point_of_sale_outlined,
  AppSection.users: Icons.manage_accounts_outlined,
  AppSection.stats: Icons.insights_outlined,
};

/// Главный экран: приветствие, роль, доступные разделы и права роли.
/// Состав плиток зависит от роли — различия видны сразу после входа.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user!;
    final theme = Theme.of(context);
    final sections = sectionsFor(user.role).where((s) => s != AppSection.home).toList();
    final perms = rolePermissions[user.role] ?? const {};

    return AppShell(
      section: AppSection.home,
      title: 'Кинотека — главная',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Здравствуйте, ${user.firstName.isEmpty ? user.username : user.firstName}!',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.verified_user_outlined, size: 18),
                      label: Text('Роль: ${user.role.title}'),
                    ),
                    Chip(avatar: const Icon(Icons.person_outline, size: 18), label: Text('Логин: ${user.username}')),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Доступные разделы', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final s in sections)
                      SizedBox(
                        width: 250,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => AppShell.goTo(context, s),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(_icons[s], color: theme.colorScheme.primary),
                                  const SizedBox(height: 8),
                                  Text(sectionLabel(s), style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(_descriptions[s] ?? '', style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Права роли «${user.role.title}»', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final p in Permission.values)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            perms.contains(p) ? Icons.check_circle : Icons.block,
                            color: perms.contains(p) ? Colors.green.shade600 : theme.colorScheme.outline,
                          ),
                          title: Text(p.title),
                          trailing: Text(perms.contains(p) ? 'разрешено' : 'нет'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран отказа: адрес открыт вручную, а роль не позволяет его видеть.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final theme = Theme.of(context);
    final need = from == null ? null : permissionForLocation(Uri.parse(from!).path);
    return AppShell(
      section: null,
      title: 'Доступ запрещён',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_person_outlined, size: 72, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Недостаточно прав', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              if (from != null) Text('Адрес: $from', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                need == null
                    ? 'Роль «${auth.role?.title}» не позволяет открыть этот раздел.'
                    : 'Нужно право «${need.title}», а у роли «${auth.role?.title}» его нет.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
