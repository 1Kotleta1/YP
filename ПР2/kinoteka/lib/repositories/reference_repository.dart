import '../data/seed_data.dart';
import '../models/reference.dart';

/// Справочники жанров и киностудий для фильтров и подписей.
class ReferenceRepository {
  const ReferenceRepository();

  List<Genre> get genres => seedGenres;
  List<Studio> get studios => seedStudios;

  String genreName(int id) =>
      genres.firstWhere((g) => g.id == id, orElse: () => const Genre(id: 0, name: '—')).name;

  String studioName(int id) => studios
      .firstWhere((s) => s.id == id,
          orElse: () => const Studio(id: 0, name: '—', country: ''))
      .name;
}
