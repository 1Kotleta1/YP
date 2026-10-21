import 'entity.dart';

class Movie implements Entity {
  @override
  final int id;
  final String title;
  final String originalTitle;
  final int year;
  final int duration;
  final double rating;

  /// Номер прокатного удостоверения — 9 цифр, уникален в каталоге.
  final String licenseNumber;

  /// Многие к одному: фильм снят на одной киностудии.
  final int studioId;

  /// Многие ко многим: режиссёры и жанры.
  final List<int> directorIds;
  final List<int> genreIds;
  @override
  final DateTime? deletedAt;

  const Movie({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.year,
    required this.duration,
    required this.rating,
    required this.licenseNumber,
    required this.studioId,
    required this.directorIds,
    required this.genreIds,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  Movie copyWith({
    int? id,
    String? title,
    String? originalTitle,
    int? year,
    int? duration,
    double? rating,
    String? licenseNumber,
    int? studioId,
    List<int>? directorIds,
    List<int>? genreIds,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      rating: rating ?? this.rating,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      studioId: studioId ?? this.studioId,
      directorIds: directorIds ?? this.directorIds,
      genreIds: genreIds ?? this.genreIds,
      // clearDeletedAt отличает «не менять поле» от «сбросить в null»
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'originalTitle': originalTitle,
        'year': year,
        'duration': duration,
        'rating': rating,
        'licenseNumber': licenseNumber,
        'studioId': studioId,
        'directorIds': directorIds,
        'genreIds': genreIds,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
        id: jsonInt(json['id']),
        title: jsonString(json['title']),
        originalTitle: jsonString(json['originalTitle'], jsonString(json['title'])),
        year: jsonInt(json['year']),
        duration: jsonInt(json['duration']),
        rating: jsonDouble(json['rating']),
        licenseNumber: jsonString(json['licenseNumber']),
        studioId: jsonInt(json['studioId']),
        directorIds: jsonIntList(json['directorIds']),
        genreIds: jsonIntList(json['genreIds']),
        deletedAt: jsonDate(json['deletedAt']),
      );
}
