/// Общее для всех записей каталога: идентификатор, корзина и сериализация.
abstract interface class Entity {
  int get id;
  DateTime? get deletedAt;
  bool get isDeleted;
  Map<String, dynamic> toJson();
}

// Помощники разбора данных из внешнего источника. Поле может отсутствовать,
// оказаться null или прийти другого типа — приложение при этом не падает.

int jsonInt(Object? v, [int fallback = 0]) => switch (v) {
      int x => x,
      num x => x.toInt(),
      String x => int.tryParse(x) ?? fallback,
      _ => fallback,
    };

double jsonDouble(Object? v, [double fallback = 0]) => switch (v) {
      num x => x.toDouble(),
      String x => double.tryParse(x) ?? fallback,
      _ => fallback,
    };

String jsonString(Object? v, [String fallback = '']) => v is String ? v : fallback;

List<int> jsonIntList(Object? v) =>
    v is List ? v.map((e) => jsonInt(e, -1)).where((e) => e >= 0).toList() : const [];

DateTime? jsonDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
