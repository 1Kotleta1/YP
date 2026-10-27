import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/password_rules.dart';
import '../core/api_exceptions.dart';
import '../state/theme_controller.dart';
import '../validation/validators.dart';

/// Общая рамка экранов входа и регистрации: карточка по центру.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final isDark = theme.mode == ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кинотека'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
            onPressed: theme.toggleLightDark,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.local_movies_outlined, size: 48, color: scheme.primary),
                    const SizedBox(height: 8),
                    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// Вход по логину и паролю. После входа маршрутизатор сам вернёт
/// пользователя на адрес из параметра from.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthNotifier>();
    _notice = auth.lastReason?.message;
    auth.clearReason();
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await context.read<AuthNotifier>().login(_login.text, _password.text);
    } on ApiException catch (e) {
      // Неверный пароль (401), блокировка (403), сервер недоступен —
      // понятное сообщение вместо пустого экрана
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(String login, String password) {
    _login.text = login;
    _password.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.from;
    return _AuthFrame(
      title: 'Вход в систему',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_notice != null) _Message(_notice!),
              if (from != null && from != '/' && _notice == null) _Message('Чтобы открыть $from, войдите в систему.'),
              if (_error != null) _Message(_error!, error: true),
              TextFormField(
                controller: _login,
                autofocus: true,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Введите логин' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Введите пароль' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: const Text('Войти'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Нет учётной записи? Зарегистрироваться'),
              ),
              const Divider(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Учебные учётные записи'),
                children: [
                  for (final (login, password, role) in const [
                    ('admin', 'Admin#2026', 'администратор'),
                    ('manager', 'Manager#2026', 'менеджер'),
                    ('viewer', 'Viewer#2026', 'зритель'),
                  ])
                    ListTile(
                      dense: true,
                      title: Text('$login / $password'),
                      subtitle: Text(role),
                      trailing: const Icon(Icons.input),
                      onTap: () => _fill(login, password),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Регистрация зрителя. Требования к паролю проверяются по мере ввода.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  Map<String, String> _serverErrors = const {};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Подсказка под паролем перерисовывается при каждом символе
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_login, _lastName, _firstName, _email, _password, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
        username: _login.text,
        password: _password.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
      );
    } on ValidationException catch (e) {
      // Ошибки сервера (например, занятый логин) — под соответствующими полями
      if (mounted) setState(() => _serverErrors = e.errors);
      _form.currentState?.validate();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());

  String? Function(String?) _withServer(String key, String? Function(String?) local) =>
      (v) => local(v) ?? _serverErrors[key];

  @override
  Widget build(BuildContext context) {
    final password = _password.text;
    final scheme = Theme.of(context).colorScheme;
    return _AuthFrame(
      title: 'Регистрация зрителя',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) _Message(_error!, error: true),
            TextFormField(
              controller: _login,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _decoration('Логин', Icons.person_outline),
              validator: _withServer('username', validateLogin),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              decoration: _decoration('Фамилия', Icons.badge_outlined),
              validator: _withServer('lastName', Validators.all([Validators.required(), Validators.personName()])),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstName,
              decoration: _decoration('Имя', Icons.badge_outlined),
              validator: _withServer('firstName', Validators.all([Validators.required(), Validators.personName()])),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoration('Почта', Icons.alternate_email),
              validator: _withServer('email', Validators.all([Validators.required(), Validators.email()])),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _decoration('Пароль', Icons.lock_outline),
              validator: _withServer('password', validatePassword),
            ),
            const SizedBox(height: 8),
            // Требования к паролю — по мере ввода, а не только по кнопке
            for (final rule in passwordRules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      rule.test(password) ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: rule.test(password) ? Colors.green.shade600 : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rule.label)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeat,
              obscureText: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _decoration('Повтор пароля', Icons.lock_reset),
              validator: (v) => v != _password.text ? 'Пароли не совпадают' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.how_to_reg),
              label: const Text('Зарегистрироваться'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/login'), child: const Text('Уже есть учётная запись? Войти')),
          ],
        ),
      ),
    );
  }
}
