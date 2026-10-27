import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/unsaved_changes.dart';
import 'form_fields.dart';
import 'leave_dialog.dart';

/// Общая форма создания и изменения для любой сущности.
///
/// Экран сущности передаёт только начальные значения, описание полей и
/// функцию сохранения; разметка, проверка, показ ошибок сервера по полям,
/// индикатор сохранения и защита от потери изменений — здесь.
class EntityForm extends StatefulWidget {
  const EntityForm({
    super.key,
    required this.title,
    required this.isEditing,
    required this.initialValues,
    required this.fields,
    required this.onSubmit,
    required this.onSaved,
    required this.onCancel,
  });

  final String title;
  final bool isEditing;
  final Map<String, Object?> initialValues;

  /// Поля строятся по текущим значениям — так работает каскад списков.
  final List<FieldSpec> Function(Map<String, Object?> values, void Function(String key, Object? value) set) fields;

  /// Сохранение. Возвращает ошибки по полям или пустой словарь.
  final Future<Map<String, String>> Function(Map<String, Object?> values) onSubmit;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> implements FormBinding {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, Object?> _values = {...widget.initialValues};
  final Map<String, TextEditingController> _controllers = {};
  Map<String, String> _external = {};
  bool _saving = false;
  bool _submitted = false;
  // Берётся сразу: в dispose() обращаться к предкам через context уже нельзя,
  // а форма может закрыться, ни разу не изменившись
  late final UnsavedChanges _guard;

  @override
  void initState() {
    super.initState();
    _guard = context.read<UnsavedChanges>();
  }

  /// Ключи на «_» — служебные (например, переключатель каскада), в данные не входят.
  bool get _dirty => widget.initialValues.keys
      .followedBy(_values.keys)
      .where((k) => !k.startsWith('_'))
      .any((k) => !_same(widget.initialValues[k], _values[k]));

  static bool _same(Object? a, Object? b) {
    if (a is List && b is List) return setEquals(a.toSet(), b.toSet());
    return (a ?? '') == (b ?? '');
  }

  @override
  Object? value(String key) => _values[key];

  @override
  void set(String key, Object? value) {
    setState(() {
      _values[key] = value;
      _external.remove(key); // после правки поле проверяется заново
      _guard.dirty = _dirty;
    });
  }

  @override
  TextEditingController controller(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: (_values[key] ?? '').toString()));

  @override
  String? externalError(String key) => _external[key];

  @override
  void dispose() {
    _guard.dirty = false;
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ключи всех полей формы, включая вложенные группы.
  static Iterable<String> _keysOf(List<FieldSpec> fields) sync* {
    for (final f in fields) {
      yield f.key;
      if (f is GroupFieldSpec) yield* _keysOf(f.children);
    }
  }

  Future<void> _submit() async {
    // Повторное нажатие во время отправки не создаёт вторую запись
    if (_saving) return;
    setState(() {
      _submitted = true;
      _external = {};
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final errors = await widget.onSubmit({..._values});
      if (!mounted) return;
      if (errors.isNotEmpty) {
        // Ошибки сервера (422) — под своими полями; то, чему поля нет, — сообщением
        final known = _keysOf(widget.fields(_values, set)).toSet();
        final orphan = errors.entries.where((e) => !known.contains(e.key)).map((e) => e.value);
        setState(() => _external = errors);
        _formKey.currentState!.validate();
        if (orphan.isNotEmpty) _snack('Сервер отклонил данные: ${orphan.join('; ')}');
        return;
      }
      _guard.dirty = false;
      widget.onSaved();
    } catch (e) {
      // 409, недоступность сервера и прочее — понятным сообщением
      _snack('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 6)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dirty = _dirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmLeave(context)) {
          _guard.dirty = false;
          widget.onCancel();
        }
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(widget.title, style: theme.textTheme.headlineSmall)),
                          if (dirty)
                            Chip(
                              avatar: const Icon(Icons.edit, size: 16),
                              label: const Text('Есть изменения'),
                              backgroundColor: theme.colorScheme.tertiaryContainer,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FieldLayout(fields: widget.fields(_values, set), binding: this),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(onPressed: _saving ? null : widget.onCancel, child: const Text('Отмена')),
                          FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: Text(widget.isEditing ? 'Сохранить изменения' : 'Создать'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
