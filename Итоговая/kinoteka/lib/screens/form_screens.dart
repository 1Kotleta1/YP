import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/director.dart';
import '../models/entity.dart';
import '../models/genre.dart';
import '../models/movie.dart';
import '../models/studio.dart';
import '../models/viewer.dart';
import '../state/form_notifier.dart';
import '../state/lookups.dart';
import '../state/paged_list_notifier.dart' show LoadStatus;
import '../validation/validators.dart';
import '../widgets/app_shell.dart';
import '../widgets/entity_form.dart';
import '../widgets/form_fields.dart';
import '../widgets/state_views.dart';

final _thisYear = DateTime.now().year;

/// Обвязка формы: загрузка записи при изменении, справочники и заголовок.
/// Создание и изменение — один экран; различие только в наличии id.
class FormFrame<T extends Entity> extends StatelessWidget {
  const FormFrame({super.key, required this.section, required this.path, required this.noun, required this.builder});

  final AppSection section;
  final String path;

  /// «фильма», «режиссёра»… — для заголовка.
  final String noun;
  final Widget Function(BuildContext context, FormNotifier<T> n, String backTo) builder;

  @override
  Widget build(BuildContext context) {
    final n = context.watch<FormNotifier<T>>();
    final lookups = context.watch<Lookups>();
    final backTo = n.isEditing ? '$path/${n.id}' : path;
    final Widget body;
    if (n.status == LoadStatus.error) {
      body = ErrorView(message: n.error ?? '', onRetry: n.load);
    } else if (lookups.status == LoadStatus.error) {
      body = ErrorView(message: lookups.error ?? '', onRetry: lookups.load);
    } else if (n.status != LoadStatus.success || !lookups.loaded) {
      body = const LoadingView();
    } else if (n.notFound) {
      body = EmptyView(message: 'Запись с номером ${n.id} не найдена.');
    } else {
      body = builder(context, n, backTo);
    }
    return AppShell(
      section: section,
      title: n.isEditing ? 'Изменение $noun' : 'Создание $noun',
      leading: IconButton(tooltip: 'Назад', icon: const Icon(Icons.arrow_back), onPressed: () => context.go(backTo)),
      child: body,
    );
  }
}

String _s(Map<String, Object?> v, String k) => ((v[k] ?? '') as String).trim();
int _i(Map<String, Object?> v, String k) => int.parse(_s(v, k));
List<int> _l(Map<String, Object?> v, String k) => List<int>.from((v[k] as List?) ?? const []);

final _req = Validators.required();
Validator _text(int max) => Validators.all([_req, Validators.maxLength(max)]);
Validator _name() => Validators.all([_req, Validators.maxLength(50), Validators.personName()]);

// ---------------------------------------------------------------- фильм

class MovieFormScreen extends StatelessWidget {
  const MovieFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormFrame<Movie>(
      section: AppSection.movies,
      path: '/movies',
      noun: 'фильма',
      builder: (context, n, backTo) {
        final refs = context.read<Lookups>();
        final m = n.item;
        return EntityForm(
          key: ValueKey(m?.id),
          title: m == null ? 'Новый фильм' : m.title,
          isEditing: n.isEditing,
          initialValues: {
            'title': m?.title ?? '',
            'originalTitle': m?.originalTitle ?? '',
            'year': m?.year.toString() ?? '',
            'duration': m?.duration.toString() ?? '',
            'rating': m?.rating.toString() ?? '',
            'licenseNumber': m?.licenseNumber ?? '',
            'studioId': m?.studioId,
            'directorIds': m?.directorIds ?? const <int>[],
            'genreIds': m?.genreIds ?? const <int>[],
          },
          fields: (v, set) {
            // Каскад: после выбора студии в списке режиссёров остаются те,
            // кто уже снимал на ней; выбранные ранее не пропадают.
            final studioId = v['studioId'] as int?;
            final showAll = v['_allDirectors'] == true;
            final selected = _l(v, 'directorIds');
            final ofStudio = studioId == null ? const <int>{} : refs.directorsOfStudio(studioId);
            final narrowed = studioId != null && !showAll && ofStudio.isNotEmpty;
            final directors = refs.directors.where(
              (d) => !narrowed || ofStudio.contains(d.id) || selected.contains(d.id),
            );
            return [
              TextFieldSpec('title', 'Название', validator: _text(100), half: true),
              TextFieldSpec('originalTitle', 'Оригинальное название', validator: _text(100), half: true),
              TextFieldSpec(
                'year',
                'Год выпуска',
                numeric: true,
                half: true,
                validator: Validators.all([_req, Validators.intRange(1895, _thisYear + 3)]),
              ),
              TextFieldSpec(
                'duration',
                'Длительность, мин',
                numeric: true,
                half: true,
                validator: Validators.all([_req, Validators.positive(), Validators.intRange(1, 600)]),
              ),
              TextFieldSpec(
                'rating',
                'Рейтинг (0–10)',
                numeric: true,
                decimal: true,
                half: true,
                validator: Validators.all([_req, Validators.doubleRange(0, 10)]),
              ),
              TextFieldSpec(
                'licenseNumber',
                'Прокатное удостоверение',
                numeric: true,
                half: true,
                hint: '121012345',
                validator: Validators.all([_req, Validators.digits(9)]),
              ),
              DropdownFieldSpec<int>(
                'studioId',
                'Киностудия',
                helper: 'Многие к одному: фильм снят на одной студии',
                options: {for (final s in refs.studios) s.id: '${s.name} (${s.country})'},
                validator: Validators.selected('Выберите киностудию'),
              ),
              MultiSelectFieldSpec(
                'directorIds',
                'Режиссёры',
                helper: narrowed
                    ? 'Показаны режиссёры, уже работавшие со студией «${refs.studioName(studioId)}»'
                    : 'Многие ко многим: один или несколько режиссёров',
                options: {for (final d in directors) d.id: d.fullName},
                validator: Validators.atLeastOne('Выберите хотя бы одного режиссёра', max: 3),
                footer: studioId == null
                    ? null
                    : FilterChip(
                        avatar: const Icon(Icons.filter_alt_off, size: 18),
                        label: const Text('Показать всех режиссёров'),
                        selected: showAll,
                        onSelected: (x) => set('_allDirectors', x),
                      ),
              ),
              MultiSelectFieldSpec(
                'genreIds',
                'Жанры',
                helper: 'Многие ко многим: от одного до пяти жанров',
                options: {for (final g in refs.genres) g.id: g.name},
                validator: Validators.atLeastOne('Выберите хотя бы один жанр', max: 5),
              ),
            ];
          },
          onSubmit: (v) => n.save(
            Movie(
              id: m?.id ?? 0,
              title: _s(v, 'title'),
              originalTitle: _s(v, 'originalTitle'),
              year: _i(v, 'year'),
              duration: _i(v, 'duration'),
              rating: double.parse(_s(v, 'rating').replaceAll(',', '.')),
              licenseNumber: _s(v, 'licenseNumber'),
              studioId: v['studioId'] as int,
              directorIds: _l(v, 'directorIds'),
              genreIds: _l(v, 'genreIds'),
              deletedAt: m?.deletedAt,
            ),
          ),
          onSaved: () => context.go('/movies/${n.item!.id}'),
          onCancel: () => context.go(backTo),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- режиссёр

class DirectorFormScreen extends StatelessWidget {
  const DirectorFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormFrame<Director>(
      section: AppSection.directors,
      path: '/directors',
      noun: 'режиссёра',
      builder: (context, n, backTo) {
        final d = n.item;
        return EntityForm(
          key: ValueKey(d?.id),
          title: d == null ? 'Новый режиссёр' : d.fullName,
          isEditing: n.isEditing,
          initialValues: {
            'lastName': d?.lastName ?? '',
            'firstName': d?.firstName ?? '',
            'country': d?.country ?? '',
            'birthYear': d?.birthYear.toString() ?? '',
          },
          fields: (v, set) => [
            TextFieldSpec('lastName', 'Фамилия', validator: _name(), half: true),
            TextFieldSpec('firstName', 'Имя', validator: _name(), half: true),
            TextFieldSpec('country', 'Страна', validator: _text(50), half: true),
            TextFieldSpec(
              'birthYear',
              'Год рождения',
              numeric: true,
              half: true,
              validator: Validators.all([_req, Validators.intRange(1850, _thisYear - 10)]),
            ),
          ],
          onSubmit: (v) => n.save(
            Director(
              id: d?.id ?? 0,
              lastName: _s(v, 'lastName'),
              firstName: _s(v, 'firstName'),
              country: _s(v, 'country'),
              birthYear: _i(v, 'birthYear'),
              deletedAt: d?.deletedAt,
            ),
          ),
          onSaved: () => context.go('/directors/${n.item!.id}'),
          onCancel: () => context.go(backTo),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- жанр

class GenreFormScreen extends StatelessWidget {
  const GenreFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormFrame<Genre>(
      section: AppSection.genres,
      path: '/genres',
      noun: 'жанра',
      builder: (context, n, backTo) {
        final g = n.item;
        return EntityForm(
          key: ValueKey(g?.id),
          title: g == null ? 'Новый жанр' : g.name,
          isEditing: n.isEditing,
          initialValues: {'name': g?.name ?? '', 'category': g?.category, 'description': g?.description ?? ''},
          fields: (v, set) => [
            TextFieldSpec('name', 'Название', validator: _text(30), half: true),
            DropdownFieldSpec<String>(
              'category',
              'Категория',
              half: true,
              options: {for (final c in Genre.categories) c: c},
              validator: Validators.selected('Выберите категорию'),
            ),
            TextFieldSpec('description', 'Описание', maxLines: 3, maxLength: 300, validator: Validators.maxLength(300)),
          ],
          onSubmit: (v) => n.save(
            Genre(
              id: g?.id ?? 0,
              name: _s(v, 'name'),
              category: v['category'] as String,
              description: _s(v, 'description'),
              deletedAt: g?.deletedAt,
            ),
          ),
          onSaved: () => context.go('/genres/${n.item!.id}'),
          onCancel: () => context.go(backTo),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- киностудия

class StudioFormScreen extends StatelessWidget {
  const StudioFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormFrame<Studio>(
      section: AppSection.studios,
      path: '/studios',
      noun: 'киностудии',
      builder: (context, n, backTo) {
        final s = n.item;
        return EntityForm(
          key: ValueKey(s?.id),
          title: s == null ? 'Новая киностудия' : s.name,
          isEditing: n.isEditing,
          initialValues: {
            'name': s?.name ?? '',
            'country': s?.country ?? '',
            'foundedYear': s?.foundedYear.toString() ?? '',
          },
          fields: (v, set) => [
            TextFieldSpec('name', 'Название', validator: _text(60)),
            TextFieldSpec('country', 'Страна', validator: _text(50), half: true),
            TextFieldSpec(
              'foundedYear',
              'Год основания',
              numeric: true,
              half: true,
              validator: Validators.all([_req, Validators.intRange(1880, _thisYear)]),
            ),
          ],
          onSubmit: (v) => n.save(
            Studio(
              id: s?.id ?? 0,
              name: _s(v, 'name'),
              country: _s(v, 'country'),
              foundedYear: _i(v, 'foundedYear'),
              deletedAt: s?.deletedAt,
            ),
          ),
          onSaved: () => context.go('/studios/${n.item!.id}'),
          onCancel: () => context.go(backTo),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- зритель с картой

class ViewerFormScreen extends StatelessWidget {
  const ViewerFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormFrame<Viewer>(
      section: AppSection.viewers,
      path: '/viewers',
      noun: 'зрителя',
      builder: (context, n, backTo) {
        final v0 = n.item;
        return EntityForm(
          key: ValueKey(v0?.id),
          title: v0 == null ? 'Новый зритель' : v0.fullName,
          isEditing: n.isEditing,
          initialValues: {
            'lastName': v0?.lastName ?? '',
            'firstName': v0?.firstName ?? '',
            'email': v0?.email ?? '',
            'phone': v0?.phone ?? '',
            'cardNumber': v0?.card.number ?? '',
            'tariff': v0?.card.tariff,
            'visitsLeft': v0?.card.visitsLeft.toString() ?? '',
            'issuedAt': v0?.card.issuedAt ?? '',
          },
          fields: (v, set) => [
            TextFieldSpec('lastName', 'Фамилия', validator: _name(), half: true),
            TextFieldSpec('firstName', 'Имя', validator: _name(), half: true),
            TextFieldSpec(
              'email',
              'Электронная почта',
              half: true,
              hint: 'name@mail.ru',
              validator: Validators.all([_req, Validators.maxLength(80), Validators.email()]),
            ),
            TextFieldSpec(
              'phone',
              'Телефон (необязательно)',
              half: true,
              hint: '+79161234567',
              validator: Validators.optional(Validators.phone()),
            ),
            // Один к одному: карта редактируется прямо в форме зрителя
            GroupFieldSpec(
              'card',
              'Карта зрителя',
              icon: Icons.credit_card,
              children: [
                TextFieldSpec(
                  'cardNumber',
                  'Номер карты',
                  half: true,
                  hint: 'KT-123456',
                  validator: Validators.all([_req, Validators.pattern(RegExp(r'^KT-\d{6}$'), 'Формат KT-123456')]),
                ),
                DropdownFieldSpec<String>(
                  'tariff',
                  'Тариф',
                  half: true,
                  options: {for (final t in ViewerCard.tariffs) t: t},
                  validator: Validators.selected('Выберите тариф'),
                ),
                TextFieldSpec(
                  'visitsLeft',
                  'Осталось посещений',
                  numeric: true,
                  half: true,
                  validator: Validators.all([_req, Validators.nonNegative(), Validators.intRange(0, 100)]),
                ),
                TextFieldSpec(
                  'issuedAt',
                  'Дата выдачи',
                  half: true,
                  hint: 'ДД.ММ.ГГГГ',
                  validator: Validators.all([_req, Validators.pastDate()]),
                ),
              ],
            ),
          ],
          onSubmit: (v) => n.save(
            Viewer(
              id: v0?.id ?? 0,
              lastName: _s(v, 'lastName'),
              firstName: _s(v, 'firstName'),
              email: _s(v, 'email'),
              phone: _s(v, 'phone'),
              card: ViewerCard(
                number: _s(v, 'cardNumber').toUpperCase(),
                tariff: v['tariff'] as String,
                visitsLeft: _i(v, 'visitsLeft'),
                issuedAt: _s(v, 'issuedAt'),
              ),
              deletedAt: v0?.deletedAt,
            ),
          ),
          onSaved: () => context.go('/viewers/${n.item!.id}'),
          onCancel: () => context.go(backTo),
        );
      },
    );
  }
}
