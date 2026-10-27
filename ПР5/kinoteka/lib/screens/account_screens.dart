import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/simple_query.dart';
import '../models/viewer.dart';
import '../repositories/account_repositories.dart';
import '../repositories/entity_repository.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/delete_dialog.dart';
import '../widgets/state_views.dart';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
}

String _date(DateTime? t) {
  if (t == null) return '—';
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Загрузка данных экрана с четырьмя состояниями — как у списков.
mixin _Loader<W extends StatefulWidget, T> on State<W> {
  T? data;
  String? error;
  LoadStatus status = LoadStatus.idle;

  Future<T> fetch();

  Future<void> load() async {
    setState(() {
      status = LoadStatus.loading;
      error = null;
    });
    try {
      final result = await fetch();
      if (!mounted) return;
      setState(() {
        data = result;
        status = LoadStatus.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        status = LoadStatus.error;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Widget body(Widget Function(T data) builder) => switch (status) {
        LoadStatus.error => ErrorView(message: error ?? '', onRetry: load),
        LoadStatus.success when data != null => builder(data as T),
        _ => const LoadingView(),
      };
}

Widget _page(Widget child, {double maxWidth = 900}) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      ),
    );

// ---------------------------------------------------------------- зритель

/// Своя карта зрителя: остаток посещений, история, продление абонемента.
/// Экран есть только у роли «зритель».
class MyCardScreen extends StatefulWidget {
  const MyCardScreen({super.key});

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> with _Loader<MyCardScreen, MyCard> {
  bool _renewing = false;

  @override
  Future<MyCard> fetch() => context.read<AccountRepository>().myCard();

  Future<void> _renew() async {
    setState(() => _renewing = true);
    try {
      final before = data?.viewer.card.visitsLeft ?? 0;
      final card = await context.read<AccountRepository>().renewCard();
      if (!mounted) return;
      setState(() => data = card);
      _snack(context, 'Абонемент продлён: +${card.viewer.card.visitsLeft - before} посещений');
    } on ConflictException catch (e) {
      if (mounted) await showDeleteBlocked(context, e.message, title: 'Продление невозможно');
    } on ApiException catch (e) {
      if (mounted) _snack(context, 'Не удалось продлить: $e');
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      section: AppSection.myCard,
      title: 'Моя карта зрителя',
      child: body((c) {
        final v = c.viewer;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return _page(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.credit_card, size: 56, color: scheme.onPrimaryContainer),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.card.number,
                            style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer)),
                        Text('${v.fullName} · тариф «${v.card.tariff}» · выдана ${v.card.issuedAt}',
                            style: TextStyle(color: scheme.onPrimaryContainer)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('${v.card.visitsLeft}',
                            style: theme.textTheme.displaySmall?.copyWith(color: scheme.onPrimaryContainer)),
                        Text('посещений осталось', style: TextStyle(color: scheme.onPrimaryContainer)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _renewing ? null : _renew,
                icon: _renewing
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.autorenew),
                label: const Text('Продлить абонемент'),
              ),
            ),
            const SizedBox(height: 24),
            Text('История карты', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: c.history.isEmpty
                  ? const ListTile(title: Text('Посещений пока не было'))
                  : Column(children: [
                      for (final e in c.history)
                        ListTile(
                          leading: Icon(e.isVisit ? Icons.confirmation_number_outlined : Icons.autorenew),
                          title: Text(e.isVisit ? 'Посещение' : 'Продление абонемента'),
                          subtitle: Text('${_date(e.at)} · ${e.by}'),
                          trailing: Text(e.delta > 0 ? '+${e.delta}' : '${e.delta}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: e.delta > 0 ? Colors.green.shade700 : scheme.error)),
                        ),
                    ]),
            ),
          ],
        ));
      }),
    );
  }
}

// ---------------------------------------------------------------- менеджер

/// Касса: поиск зрителя по карте или фамилии и отметка посещения.
/// Экран есть только у роли «менеджер».
class BoxOfficeScreen extends StatefulWidget {
  const BoxOfficeScreen({super.key});

  @override
  State<BoxOfficeScreen> createState() => _BoxOfficeScreenState();
}

class _BoxOfficeScreenState extends State<BoxOfficeScreen> {
  final _search = TextEditingController();
  List<Viewer> _found = const [];
  bool _searching = false;
  String? _error;
  int? _busyId;
  final List<String> _log = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final text = _search.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final page = await context
          .read<ViewerRepository>()
          .find(SimpleQuery(viewerQuerySpec).copyWith(search: text, size: 10));
      if (mounted) setState(() => _found = page.items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _visit(Viewer v) async {
    setState(() => _busyId = v.id);
    try {
      final updated = await context.read<ViewerRepository>().registerVisit(v.id);
      if (!mounted) return;
      setState(() {
        _found = [for (final x in _found) x.id == v.id ? updated : x];
        _log.insert(0, '${TimeOfDay.now().format(context)} — ${v.fullName}, ${v.card.number}: '
            'осталось ${updated.card.visitsLeft}');
      });
      context.read<ViewerListNotifier>().refresh();
    } on ConflictException catch (e) {
      if (mounted) await showDeleteBlocked(context, e.message, title: 'Посещение не отмечено');
    } on ForbiddenException catch (e) {
      if (mounted) await showForbidden(context, e.message);
    } on ApiException catch (e) {
      if (mounted) _snack(context, 'Не удалось отметить посещение: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppShell(
      section: AppSection.boxOffice,
      title: 'Касса',
      child: _page(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onSubmitted: (_) => _find(),
                  decoration: const InputDecoration(
                    labelText: 'Номер карты (KT-…) или фамилия',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _searching ? null : _find, child: const Text('Найти')),
            ],
          ),
          const SizedBox(height: 16),
          if (_searching) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          for (final v in _found)
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text('${v.fullName} · ${v.card.number}'),
                subtitle: Text('Тариф «${v.card.tariff}», посещений осталось: ${v.card.visitsLeft}'),
                trailing: FilledButton.icon(
                  onPressed: _busyId == v.id ? null : () => _visit(v),
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Отметить'),
                ),
              ),
            ),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Отмечено за смену', style: theme.textTheme.titleMedium),
            for (final line in _log) ListTile(dense: true, leading: const Icon(Icons.check), title: Text(line)),
          ],
        ],
      )),
    );
  }
}

// ---------------------------------------------------------------- администратор

/// Пользователи и роли. Экран есть только у роли «администратор».
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with _Loader<UsersScreen, List<AppUser>> {
  @override
  Future<List<AppUser>> fetch() => context.read<AccountRepository>().users();

  Future<void> _update(AppUser u, {Role? role, bool? blocked}) async {
    try {
      final updated = await context.read<AccountRepository>().updateUser(u.id, role: role?.code, blocked: blocked);
      if (!mounted) return;
      setState(() => data = [for (final x in data!) x.id == u.id ? updated : x]);
      _snack(context, '${updated.username}: роль «${updated.role.title}»${updated.blocked ? ', заблокирован' : ''}. '
          'Его прежние токены больше не действуют.');
    } on ApiException catch (e) {
      if (mounted) _snack(context, 'Не удалось изменить пользователя: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthNotifier>().user;
    return AppShell(
      section: AppSection.users,
      title: 'Пользователи и роли',
      onReload: load,
      child: body((users) => _page(
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Логин')),
                    DataColumn(label: Text('Имя')),
                    DataColumn(label: Text('Роль')),
                    DataColumn(label: Text('Заблокирован')),
                  ],
                  rows: [
                    for (final u in users)
                      DataRow(cells: [
                        DataCell(Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(u.displayName)),
                        DataCell(DropdownButton<Role>(
                          value: u.role,
                          underline: const SizedBox.shrink(),
                          onChanged: u.id == me?.id ? null : (r) => _update(u, role: r),
                          items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.title))],
                        )),
                        DataCell(Switch(
                          value: u.blocked,
                          onChanged: u.id == me?.id ? null : (b) => _update(u, blocked: b),
                        )),
                      ]),
                  ],
                ),
              ),
            ),
          )),
    );
  }
}

/// Сводка для администратора.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with _Loader<StatsScreen, AppStats> {
  @override
  Future<AppStats> fetch() => context.read<AccountRepository>().stats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(String label, String value, IconData icon, {String? hint}) => SizedBox(
          width: 210,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(value, style: theme.textTheme.headlineMedium),
                  Text(label),
                  if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
    return AppShell(
      section: AppSection.stats,
      title: 'Статистика',
      onReload: load,
      child: body((s) => _page(
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                tile('фильмов', '${s.alive('movies')}', Icons.movie_outlined, hint: 'в корзине: ${s.deleted('movies')}'),
                tile('режиссёров', '${s.alive('directors')}', Icons.people_outline,
                    hint: 'в корзине: ${s.deleted('directors')}'),
                tile('жанров', '${s.alive('genres')}', Icons.local_offer_outlined,
                    hint: 'в корзине: ${s.deleted('genres')}'),
                tile('киностудий', '${s.alive('studios')}', Icons.business_outlined,
                    hint: 'в корзине: ${s.deleted('studios')}'),
                tile('зрителей', '${s.alive('viewers')}', Icons.badge_outlined,
                    hint: 'в корзине: ${s.deleted('viewers')}'),
                tile('посещений всего', '${s.visitsTotal}', Icons.confirmation_number_outlined,
                    hint: 'за 7 дней: ${s.visitsWeek}'),
                tile('посещений на картах', '${s.visitsLeft}', Icons.credit_card_outlined),
                tile('пользователей', '${Role.values.fold(0, (n, r) => n + s.usersWithRole(r.code))}',
                    Icons.manage_accounts_outlined,
                    hint: Role.values.map((r) => '${r.title.toLowerCase()}: ${s.usersWithRole(r.code)}').join(', ')),
                tile('активных сессий', '${s.activeSessions}', Icons.key_outlined,
                    hint: 'заблокировано учётных записей: ${s.blockedUsers}'),
              ],
            ),
            maxWidth: 1000,
          )),
    );
  }
}
