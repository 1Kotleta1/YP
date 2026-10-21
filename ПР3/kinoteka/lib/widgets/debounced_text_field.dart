import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поле ввода, которое сообщает о значении только после паузы в наборе.
///
/// Без задержки выборка запускалась бы на каждый символ.
class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.icon,
    this.width,
    this.digitsOnly = false,
    this.delay = const Duration(milliseconds: 400),
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final IconData? icon;
  final double? width;
  final bool digitsOnly;
  final Duration delay;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(covariant DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Значение сменилось извне (кнопка «назад», сброс фильтров) —
    // показываем его, если пользователь сейчас не печатает
    final typing = _timer?.isActive ?? false;
    if (!typing && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  void _schedule(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () => widget.onChanged(text.trim()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        onChanged: _schedule,
        keyboardType: widget.digitsOnly ? TextInputType.number : null,
        inputFormatters: widget.digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]
            : null,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: widget.icon == null ? null : Icon(widget.icon),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Очистить',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _timer?.cancel();
                      _controller.clear();
                      widget.onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
