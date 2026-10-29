import 'package:flutter/material.dart';

import '../core/breakpoints.dart';

/// Панель фильтров: на широком окне раскрыта всегда,
/// на узком сворачивается, чтобы не занимать половину экрана.
class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key, required this.children, required this.activeCount});

  final List<Widget> children;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final fields = Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: children);

    if (context.windowSize >= WindowSize.medium) {
      return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: fields);
    }
    // Раскрытие панели — локальное состояние виджета, его хранит ExpansionTile
    return ExpansionTile(
      leading: const Icon(Icons.filter_list),
      title: Text(activeCount == 0 ? 'Поиск и фильтры' : 'Поиск и фильтры (активно: $activeCount)'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [fields],
    );
  }
}

/// Выпадающий список фильтра с пунктом «все».
class FilterDropdown<V> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 220,
  });

  final String label;
  final String allLabel;
  final V? value;
  final Map<V, String> options;
  final ValueChanged<V?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<V?>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: [
          DropdownMenuItem<V?>(value: null, child: Text(allLabel)),
          for (final e in options.entries)
            DropdownMenuItem<V?>(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
