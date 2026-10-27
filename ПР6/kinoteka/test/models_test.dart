import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/models/movie.dart';
import 'package:kinoteka/models/viewer.dart';
import 'package:kinoteka/repositories/api_repository.dart';

void main() {
  group('Разбор моделей', () {
    test('отсутствующие поля не приводят к исключению', () {
      final movie = Movie.fromJson({'id': 1});
      expect(movie.title, '');
      expect(movie.year, 0);
      expect(movie.directorIds, isEmpty);
      expect(movie.deletedAt, isNull);
    });

    test('числа строкой и связи объектами разбираются', () {
      final movie = Movie.fromJson({
        'id': '7',
        'title': 'Сталкер',
        'year': '1979',
        'rating': 8.1,
        'studio': {'id': 2, 'name': 'Мосфильм'},
        'directors': [
          {'id': 5},
        ],
        'genres': [1, 'x', 3],
      });
      expect(movie.id, 7);
      expect(movie.year, 1979);
      expect(movie.originalTitle, 'Сталкер');
      expect(movie.studioId, 2);
      expect(movie.directorIds, [5]);
      expect(movie.genreIds, [1, 3]);
    });

    test('неизвестный тариф карты заменяется базовым, карта без полей — пустой', () {
      final viewer = Viewer.fromJson({
        'id': 3,
        'card': {'number': 'KT-0003', 'tariff': 'VIP', 'visitsLeft': null},
      });
      expect(viewer.card.tariff, 'Базовый');
      expect(viewer.card.visitsLeft, 0);
      expect(Viewer.fromJson({'id': 4}).card, same(ViewerCard.empty));
    });

    test('страница списка: значения по умолчанию, если сервер их не прислал', () {
      final page = parsePage<Movie>(
        {
          'items': [
            {'id': 1, 'title': 'Солярис'},
          ],
        },
        Movie.fromJson,
        20,
      );
      expect(page.items.single.title, 'Солярис');
      expect(page.page, 1);
      expect(page.size, 20);
      expect(page.total, 0);
    });
  });
}
