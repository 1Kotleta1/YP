/// Требования к паролю при регистрации. Те же правила проверяет сервер:
/// клиентская проверка нужна для подсказки по мере ввода, а не для защиты.
class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String password) test;
}

final passwordRules = <PasswordRule>[
  PasswordRule('не короче 8 символов', (p) => p.length >= 8),
  PasswordRule('хотя бы одна цифра', (p) => RegExp(r'\d').hasMatch(p)),
  PasswordRule('хотя бы один специальный символ (!, #, %, …)',
      (p) => RegExp(r'[^A-Za-zА-Яа-яЁё0-9\s]').hasMatch(p)),
];

/// null — пароль подходит, иначе — список невыполненных требований.
String? validatePassword(String? value) {
  final p = value ?? '';
  if (p.isEmpty) return 'Введите пароль';
  final failed = [for (final r in passwordRules) if (!r.test(p)) r.label];
  return failed.isEmpty ? null : 'Нужно: ${failed.join(', ')}';
}

final _loginRe = RegExp(r'^[a-z0-9_.-]{3,30}$');

String? validateLogin(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Введите логин';
  if (!_loginRe.hasMatch(v)) return 'От 3 до 30 символов: строчные латинские буквы, цифры, точка, дефис, _';
  return null;
}
