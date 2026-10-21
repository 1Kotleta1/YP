import '../models/movie.dart';
import 'entity_repository.dart';

/// Удаление запрещено: на запись ссылаются другие записи.
class DeleteBlockedException implements Exception {
  const DeleteBlockedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// «фильм», «фильма», «фильмов» в зависимости от числа.
String moviesWord(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'фильм';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'фильма';
  return 'фильмов';
}

/// Проверки ссылочной целостности перед удалением.
///
/// Киностудию (один ко многим) нельзя удалить ни в корзину, ни навсегда,
/// пока на неё ссылаются фильмы. Режиссёра и жанр (многие ко многим) можно
/// убрать в корзину, но нельзя стереть навсегда.
class RelationGuard {
  RelationGuard(this._movies);

  final MovieRepository _movies;

  Future<List<Movie>> _using(bool Function(Movie m) test) async =>
      (await _movies.findAll(includeDeleted: true)).where(test).toList();

  Future<String?> studios(List<int> ids, {required bool permanent}) async {
    final used = await _using((m) => ids.contains(m.studioId));
    if (used.isEmpty) return null;
    return 'Нельзя удалить киностудию: на неё ${used.length % 10 == 1 && used.length % 100 != 11 ? 'ссылается' : 'ссылаются'} '
        '${used.length} ${moviesWord(used.length)} '
        '(например, «${used.first.title}»). Сначала укажите этим фильмам другую студию.';
  }

  Future<String?> directors(List<int> ids, {required bool permanent}) async {
    if (!permanent) return null;
    final used = await _using((m) => m.directorIds.any(ids.contains));
    if (used.isEmpty) return null;
    return 'Нельзя удалить режиссёра навсегда: связанных фильмов — ${used.length}. '
        'Запись можно убрать в корзину.';
  }

  Future<String?> genres(List<int> ids, {required bool permanent}) async {
    if (!permanent) return null;
    final used = await _using((m) => m.genreIds.any(ids.contains));
    if (used.isEmpty) return null;
    return 'Нельзя удалить жанр навсегда: связанных фильмов — ${used.length}. '
        'Запись можно убрать в корзину.';
  }
}
