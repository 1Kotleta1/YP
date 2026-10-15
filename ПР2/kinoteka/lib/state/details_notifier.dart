import 'package:flutter/foundation.dart';

import '../models/director.dart';
import '../models/movie.dart';
import '../repositories/director_repository.dart';
import '../repositories/movie_repository.dart';
import 'paged_list_notifier.dart';

/// Состояние карточки записи: загрузка, найдено, не найдено, ошибка.
abstract class DetailsNotifier<T> extends ChangeNotifier {
  DetailsNotifier(this.id);

  final int id;
  T? _item;
  LoadStatus _status = LoadStatus.idle;
  String? _error;

  T? get item => _item;
  LoadStatus get status => _status;
  String? get error => _error;
  bool get notFound => _status == LoadStatus.success && _item == null;

  @protected
  Future<T?> fetch();

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _item = await fetch();
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить запись: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }
}

class MovieDetails {
  const MovieDetails(this.movie, this.directors);

  final Movie movie;
  final List<Director> directors;
}

class MovieDetailsNotifier extends DetailsNotifier<MovieDetails> {
  MovieDetailsNotifier(this._movies, this._directors, super.id);

  final MovieRepository _movies;
  final DirectorRepository _directors;

  @override
  Future<MovieDetails?> fetch() async {
    final movie = await _movies.findById(id);
    if (movie == null) return null;
    return MovieDetails(movie, await _directors.findByIds(movie.directorIds));
  }
}

class DirectorDetails {
  const DirectorDetails(this.director, this.movies);

  final Director director;
  final List<Movie> movies;
}

class DirectorDetailsNotifier extends DetailsNotifier<DirectorDetails> {
  DirectorDetailsNotifier(this._directors, this._movies, super.id);

  final DirectorRepository _directors;
  final MovieRepository _movies;

  @override
  Future<DirectorDetails?> fetch() async {
    final director = await _directors.findById(id);
    if (director == null) return null;
    return DirectorDetails(director, await _movies.findByDirector(id));
  }
}
