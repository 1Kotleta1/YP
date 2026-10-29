import 'package:flutter/material.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';

/// Переходы по страницам, номер страницы, общее число записей
/// и выбор размера страницы.
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.result, required this.onPage, required this.onSize});

  final PageResult<Object?> result;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Первая страница',
                icon: const Icon(Icons.first_page),
                onPressed: r.hasPrevious ? () => onPage(1) : null,
              ),
              IconButton(
                tooltip: 'Предыдущая страница',
                icon: const Icon(Icons.chevron_left),
                onPressed: r.hasPrevious ? () => onPage(r.page - 1) : null,
              ),
              // На узком окне подпись переносится, а не выталкивает кнопки за край
              Flexible(child: Text('Страница ${r.page} из ${r.totalPages}', textAlign: TextAlign.center)),
              IconButton(
                tooltip: 'Следующая страница',
                icon: const Icon(Icons.chevron_right),
                onPressed: r.hasNext ? () => onPage(r.page + 1) : null,
              ),
              IconButton(
                tooltip: 'Последняя страница',
                icon: const Icon(Icons.last_page),
                onPressed: r.hasNext ? () => onPage(r.totalPages) : null,
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text('Всего записей: ${r.total}'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('На странице:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: r.size,
                    underline: const SizedBox.shrink(),
                    items: [for (final s in ListQuery.pageSizes) DropdownMenuItem(value: s, child: Text('$s'))],
                    onChanged: (v) {
                      if (v != null) onSize(v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
