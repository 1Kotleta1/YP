/// Справочники: жанры и киностудии. Не редактируются в этой работе.
class Genre {
  final int id;
  final String name;

  const Genre({required this.id, required this.name});
}

class Studio {
  final int id;
  final String name;
  final String country;

  const Studio({required this.id, required this.name, required this.country});
}
