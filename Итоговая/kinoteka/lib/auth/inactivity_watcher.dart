import 'dart:async'; // Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HardwareKeyboard, KeyEvent

import 'auth_notifier.dart';

/// Выход по неактивности.
///
/// Таймер сбрасывается при любом действии пользователя: движении мыши,
/// нажатии, прокрутке, клавиатуре. За [warning] до конца поверх экрана
/// появляется предупреждение с обратным отсчётом.
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.auth,
    required this.timeout,
    required this.warning,
    required this.child,
  });

  final AuthNotifier auth;
  final Duration timeout;
  final Duration warning;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warnTimer;
  Timer? _endTimer;
  Timer? _ticker;
  DateTime? _deadline;

  bool get _active => widget.auth.isAuthenticated;

  @override
  void initState() {
    super.initState();
    // Клавиатуру слушаем глобально: у обёртки над всем приложением нет
    // фокуса, и KeyboardListener не узнал бы о наборе текста в форме.
    HardwareKeyboard.instance.addHandler(_onKey);
    widget.auth.addListener(_onAuthChanged);
    _restart();
  }

  void _onAuthChanged() => _active ? _restart() : _stop();

  // false означает «событие не обработано, передайте его дальше».
  bool _onKey(KeyEvent event) {
    _activity();
    return false;
  }

  void _activity() {
    if (!_active) return;
    // Предупреждение снимается только кнопкой: случайное движение мыши
    // не должно молча продлевать сессию, о конце которой уже предупредили
    if (_deadline != null) return;
    _restart();
    widget.auth.touch();
  }

  void _restart() {
    _stop();
    if (!_active) return;
    _warnTimer = Timer(widget.timeout - widget.warning, _showWarning);
    _endTimer = Timer(widget.timeout, () => widget.auth.logout(reason: LogoutReason.inactivity));
  }

  void _stop() {
    _warnTimer?.cancel();
    _endTimer?.cancel();
    _ticker?.cancel();
    if (_deadline != null && mounted) setState(() => _deadline = null);
  }

  void _showWarning() {
    setState(() => _deadline = DateTime.now().add(widget.warning));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _continue() {
    setState(() => _deadline = null);
    _restart();
    widget.auth.touch(force: true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.auth.removeListener(_onAuthChanged);
    _warnTimer?.cancel();
    _endTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _deadline;
    return Stack(
      children: [
        Listener(
          // Перехват без поглощения: событие идёт дальше к виджетам.
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _activity(),
          onPointerMove: (_) => _activity(),
          onPointerHover: (_) => _activity(),
          onPointerSignal: (_) => _activity(),
          child: widget.child,
        ),
        if (deadline != null) ...[
          const ModalBarrier(dismissible: false, color: Colors.black38),
          Center(
            child: _WarningCard(deadline: deadline, onContinue: _continue, onLogout: widget.auth.logout),
          ),
        ],
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.deadline, required this.onContinue, required this.onLogout});

  final DateTime deadline;
  final VoidCallback onContinue;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final left = deadline.difference(DateTime.now()).inSeconds.clamp(0, 999);
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 48, color: theme.colorScheme.tertiary),
              const SizedBox(height: 12),
              Text('Вы здесь?', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Сессия будет завершена из-за неактивности через $left с.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(onPressed: onLogout, child: const Text('Выйти')),
                  FilledButton(autofocus: true, onPressed: onContinue, child: const Text('Продолжить работу')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
