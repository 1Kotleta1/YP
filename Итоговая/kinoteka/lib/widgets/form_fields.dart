import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Доступ поля к общему состоянию формы.
abstract interface class FormBinding {
  Object? value(String key);
  void set(String key, Object? value);
  TextEditingController controller(String key);

  /// Ошибка, пришедшая после отправки (например, дубликат).
  String? externalError(String key);
}

/// Описание одного поля формы. Сама форма — [EntityForm] — общая для всех
/// сущностей и строит поля по такому списку.
sealed class FieldSpec {
  const FieldSpec(this.key, this.label, {this.half = false});

  final String key;
  final String label;

  /// Занимать половину ширины на широком экране.
  final bool half;

  Widget build(BuildContext context, FormBinding b);
}

class TextFieldSpec extends FieldSpec {
  const TextFieldSpec(
    super.key,
    super.label, {
    this.validator,
    this.hint,
    this.helper,
    this.numeric = false,
    this.decimal = false,
    this.maxLines = 1,
    this.maxLength,
    super.half,
  });

  final FormFieldValidator<String>? validator;
  final String? hint;
  final String? helper;
  final bool numeric;
  final bool decimal;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context, FormBinding b) {
    return TextFormField(
      controller: b.controller(key),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: decimal)
          : (maxLines > 1 ? TextInputType.multiline : null),
      inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[\d.,]' : r'\d'))] : null,
      onChanged: (v) => b.set(key, v),
      validator: (v) => b.externalError(key) ?? validator?.call(v),
    );
  }
}

/// Многие к одному — выпадающий список. Значение — идентификатор, а не объект:
/// иначе без переопределения == выбранный элемент перестанет совпадать с items.
class DropdownFieldSpec<V> extends FieldSpec {
  const DropdownFieldSpec(super.key, super.label, {required this.options, this.validator, this.helper, super.half});

  final Map<V, String> options;
  final String? Function(V?)? validator;
  final String? helper;

  @override
  Widget build(BuildContext context, FormBinding b) {
    final raw = b.value(key);
    // Значения нет в items — показываем пустым, а не падаем
    final value = raw is V && options.containsKey(raw) ? raw : null;
    return DropdownButtonFormField<V>(
      key: ValueKey('$key:$value:${options.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final e in options.entries)
          DropdownMenuItem<V>(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => b.set(key, v),
      validator: (v) => b.externalError(key) ?? validator?.call(v),
    );
  }
}

/// Многие ко многим — набор FilterChip внутри собственного поля формы.
/// Поле участвует в общем validate() наравне с текстовыми.
class MultiSelectFieldSpec extends FieldSpec {
  const MultiSelectFieldSpec(super.key, super.label, {required this.options, this.validator, this.helper, this.footer});

  final Map<int, String> options;
  final String? Function(List<int>?)? validator;
  final String? helper;

  /// Дополнительный элемент под чипами (например, переключатель каскада).
  final Widget? footer;

  @override
  Widget build(BuildContext context, FormBinding b) {
    return FormField<List<int>>(
      initialValue: List<int>.from((b.value(key) as List?) ?? const <int>[]),
      validator: (v) => b.externalError(key) ?? validator?.call(v),
      builder: (field) {
        final selected = field.value ?? const <int>[];
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 2,
            errorMaxLines: 2,
            border: const OutlineInputBorder(),
            errorText: field.errorText, // ошибка — как у обычного поля
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in options.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: selected.contains(e.key),
                      onSelected: (_) {
                        final next = [...selected];
                        next.contains(e.key) ? next.remove(e.key) : next.add(e.key);
                        field.didChange(next); // без этого форма не узнает о значении
                        b.set(key, next);
                      },
                    ),
                ],
              ),
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          ),
        );
      },
    );
  }
}

/// Один к одному — вложенная группа полей (карта зрителя внутри зрителя).
class GroupFieldSpec extends FieldSpec {
  const GroupFieldSpec(super.key, super.label, {required this.children, this.icon});

  final List<FieldSpec> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context, FormBinding b) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          FieldLayout(fields: children, binding: b),
        ],
      ),
    );
  }
}

/// Раскладка полей: половинные поля встают по два в ряд на широком экране.
class FieldLayout extends StatelessWidget {
  const FieldLayout({super.key, required this.fields, required this.binding});

  final List<FieldSpec> fields;
  final FormBinding binding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        final twoColumns = c.maxWidth >= 520;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final f in fields)
              SizedBox(
                width: f.half && twoColumns ? (c.maxWidth - gap) / 2 : c.maxWidth,
                child: f.build(context, binding),
              ),
          ],
        );
      },
    );
  }
}
