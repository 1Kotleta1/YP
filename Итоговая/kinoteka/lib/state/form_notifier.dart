import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/entity.dart';
import '../repositories/entity_repository.dart';
import 'paged_list_notifier.dart';

/// Состояние экрана формы: загрузка записи для изменения и сохранение.
///
/// Один и тот же класс обслуживает создание (id == null) и изменение.
class FormNotifier<T extends Entity> extends ChangeNotifier {
  FormNotifier(this._repository, this.id, {this.errorKeys = const {}, this.onSaved});

  final EntityRepository<T, dynamic> _repository;
  final int? id;

  /// Ключ ошибки сервера → ключ поля формы, если они различаются
  /// (вложенная карта зрителя: «card.number» → «cardNumber»).
  final Map<String, String> errorKeys;
  final VoidCallback? onSaved;

  T? _item;
  LoadStatus _status = LoadStatus.idle;
  String? _error;

  bool get isEditing => id != null;
  T? get item => _item;
  LoadStatus get status => isEditing ? _status : LoadStatus.success;
  String? get error => _error;
  bool get notFound => isEditing && _status == LoadStatus.success && _item == null;

  Future<void> load() async {
    if (!isEditing) return;
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      _item = await _repository.findById(id!);
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить запись: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Возвращает ошибки по полям или пустой словарь при успехе.
  ///
  /// Уникальность номера удостоверения, почты, номера карты и названия
  /// жанра проверяет сервер: ответ 422 раскладывается по полям формы.
  /// Остальные исключения (409, сеть) уходят в форму и показываются
  /// сообщением.
  Future<Map<String, String>> save(T item) async {
    try {
      _item = isEditing ? await _repository.update(item) : await _repository.create(item);
    } on ValidationException catch (e) {
      if (e.errors.isEmpty) rethrow;
      return {for (final x in e.errors.entries) errorKeys[x.key] ?? x.key: x.value};
    }
    onSaved?.call();
    return const {};
  }
}
