class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;

  const PageResult({required this.items, required this.page, required this.size, required this.total});

  int get totalPages => total == 0 ? 1 : (total / size).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  /// Пустая страница — начальное значение для состояния экрана.
  ///
  /// Конструктор не const: пустой константный список с параметром
  /// типа `T` в Dart запрещён, поэтому пишется обычный `<T>[]`.
  PageResult.empty() : items = <T>[], page = 1, size = 10, total = 0;

  /// Вырезает страницу из уже отфильтрованного и отсортированного списка.
  factory PageResult.slice(List<T> rows, int page, int size) {
    final total = rows.length;
    final from = (page - 1) * size;
    // num.clamp возвращает num, а sublist ждёт int — границу считаем явно
    final to = (from + size) > total ? total : (from + size);
    final items = from >= total ? <T>[] : rows.sublist(from, to);
    return PageResult(items: items, page: page, size: size, total: total);
  }
}
