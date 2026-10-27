import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../models/director.dart';
import '../models/director_query.dart';
import '../models/list_query.dart';
import '../state/lookups.dart';
import '../state/paged_list_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_panel.dart';

class DirectorListScreen extends StatefulWidget {
  const DirectorListScreen({super.key, required this.query});

  final DirectorQuery query;

  @override
  State<DirectorListScreen> createState() => _DirectorListScreenState();
}

class _DirectorListScreenState extends State<DirectorListScreen> {
  @override
  void initState() {
    super.initState();
    _applyFromUrl();
  }

  @override
  void didUpdateWidget(covariant DirectorListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _applyFromUrl();
  }

  void _applyFromUrl() {
    final query = widget.query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DirectorListNotifier>().applyQuery(query);
    });
  }

  void _navigate(DirectorQuery next) => context.go(listLocation('/directors', next));

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DirectorListNotifier>();
    final q = notifier.query;
    final lookups = context.watch<Lookups>();
    final auth = context.watch<AuthNotifier>();

    return AppShell(
      section: AppSection.directors,
      title: 'Кинотека — режиссёры',
      onReload: notifier.load,
      onAdd: auth.can(Permission.catalogEdit) ? () => context.go('/directors/new') : null,
      addLabel: 'Новый режиссёр',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterPanel(
            activeCount: [q.search.isNotEmpty, q.country != null].where((x) => x).length,
            children: [
              DebouncedTextField(
                width: 300,
                label: 'Поиск по фамилии или стране',
                icon: Icons.search,
                value: q.search,
                onChanged: (v) => _navigate(q.copyWith(search: v)),
              ),
              FilterDropdown<String>(
                label: 'Страна',
                allLabel: 'Все страны',
                value: q.country,
                options: {for (final c in lookups.directorCountries) c: c},
                onChanged: (v) => _navigate(q.copyWith(country: v)),
              ),
              if (auth.can(Permission.trashView))
                FilterChip(
                  label: const Text('Показывать удалённых'),
                  selected: q.includeDeleted,
                  onSelected: (v) => _navigate(q.copyWith(includeDeleted: v)),
                ),
              if (q.hasFilters)
                TextButton.icon(
                  onPressed: () => _navigate(q.cleared()),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
            ],
          ),
          Expanded(
            child: EntityListView<Director, DirectorQuery>(
              notifier: notifier,
              onNavigate: _navigate,
              onOpen: (d) => context.go('/directors/${d.id}'),
              onEdit: (d) => context.go('/directors/${d.id}/edit'),
              isDeleted: (d) => d.isDeleted,
              describe: (d) => d.fullName,
              cardTitle: (d) => Text('${d.lastName} ${d.firstName}'),
              cardSubtitle: (d) => Text('${d.country} · ${d.birthYear} г. р.'),
              columns: [
                TableColumnSpec(
                  label: 'Фамилия',
                  sortField: 'lastName',
                  build: (d) => Text(
                    d.lastName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: d.isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                TableColumnSpec(label: 'Имя', sortField: 'firstName', build: (d) => Text(d.firstName)),
                TableColumnSpec(label: 'Страна', sortField: 'country', build: (d) => Text(d.country)),
                TableColumnSpec(
                  label: 'Год рождения',
                  sortField: 'birthYear',
                  numeric: true,
                  build: (d) => Text('${d.birthYear}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
