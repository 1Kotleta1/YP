import 'package:flutter/foundation.dart';

import '../models/entity.dart';
import '../repositories/entity_repository.dart';
import 'paged_list_notifier.dart';

/// Проверка уникальности перед сохранением: ключ поля → текст ошибки.
typedef UniqueCheck<T> = Future<Map<String, String>> Function(T item);

/// Состояние экрана формы: загрузка записи для изменения и сохранение.
///
/// Один и тот же класс обслуживает создание (id == null) и изменение.
class FormNotifier<T extends Entity> extends ChangeNotifier {
  FormNotifier(this._repository, this.id, {this.uniqueCheck, this.onSaved});

  final EntityRepository<T, dynamic> _repository;
  final int? id;
  final UniqueCheck<T>? uniqueCheck;
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

  /// Возвращает ошибки по полям (дубликаты) или пустой словарь при успехе.
  Future<Map<String, String>> save(T item) async {
    final errors = await uniqueCheck?.call(item) ?? const {};
    if (errors.isNotEmpty) return errors;
    _item = isEditing ? await _repository.update(item) : await _repository.create(item);
    onSaved?.call();
    return const {};
  }
}
