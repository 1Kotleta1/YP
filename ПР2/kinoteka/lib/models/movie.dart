class Movie {
  final int id;
  final String title;
  final String originalTitle;
  final int year;
  final int duration;
  final double rating;
  final int studioId;
  final List<int> directorIds;
  final List<int> genreIds;
  final DateTime? deletedAt;

  const Movie({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.year,
    required this.duration,
    required this.rating,
    required this.studioId,
    required this.directorIds,
    required this.genreIds,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Movie copyWith({
    String? title,
    String? originalTitle,
    int? year,
    int? duration,
    double? rating,
    int? studioId,
    List<int>? directorIds,
    List<int>? genreIds,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Movie(
      id: id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      rating: rating ?? this.rating,
      studioId: studioId ?? this.studioId,
      directorIds: directorIds ?? this.directorIds,
      genreIds: genreIds ?? this.genreIds,
      // clearDeletedAt отличает «не менять поле» от «сбросить в null»
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
