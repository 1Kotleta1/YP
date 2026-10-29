import 'package:flutter/foundation.dart';

import '../models/director.dart';
import '../models/movie.dart';
import 'paged_list_notifier.dart';

/// Состояние карточки записи: загрузка, найдено, не найдено, ошибка.
class DetailsNotifier<T> extends ChangeNotifier {
  DetailsNotifier(this.id, this._fetch);

  final int id;
  final Future<T?> Function() _fetch;
  T? _item;
  LoadStatus _status = LoadStatus.idle;
  String? _error;

  T? get item => _item;
  LoadStatus get status => _status;
  String? get error => _error;
  bool get notFound => _status == LoadStatus.success && _item == null;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _item = await _fetch();
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить запись: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }
}

/// Запись вместе со связанными фильмами — для карточек справочников.
class WithMovies<T> {
  const WithMovies(this.item, this.movies);

  final T item;
  final List<Movie> movies;
}

class MovieDetails {
  const MovieDetails(this.movie, this.directors);

  final Movie movie;
  final List<Director> directors;
}
