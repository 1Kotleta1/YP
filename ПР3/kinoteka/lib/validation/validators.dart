/// Переиспользуемые проверки полей форм.
///
/// Каждая функция возвращает FormFieldValidator: null — значение верное,
/// строка — текст ошибки, который показывается под полем.
library;

typedef Validator = String? Function(String? value);

class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-zА-Яа-я]{2,}$');
  static final _phone = RegExp(r'^\+7\d{10}$');
  static final _name = RegExp(r"^[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё' -]*$");
  static final _date = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');

  /// Объединяет проверки: возвращается первая сработавшая ошибка.
  static Validator all(List<Validator> list) => (value) {
        for (final v in list) {
          final error = v(value);
          if (error != null) return error;
        }
        return null;
      };

  /// Необязательное поле: пустое значение не проверяется дальше.
  static Validator optional(Validator inner) =>
      (value) => (value == null || value.trim().isEmpty) ? null : inner(value);

  static Validator required([String message = 'Обязательное поле']) =>
      (value) => (value == null || value.trim().isEmpty) ? message : null;

  static Validator maxLength(int max) => (value) =>
      (value ?? '').trim().length > max ? 'Не длиннее $max символов' : null;

  static Validator minLength(int min) => (value) =>
      (value ?? '').trim().length < min ? 'Не короче $min символов' : null;

  static Validator intRange(int min, int max) => (value) {
        final n = int.tryParse((value ?? '').trim());
        if (n == null) return 'Введите целое число';
        if (n < min || n > max) return 'Допустимо от $min до $max';
        return null;
      };

  static Validator doubleRange(double min, double max) => (value) {
        final n = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
        if (n == null) return 'Введите число';
        if (n < min || n > max) return 'Допустимо от $min до $max';
        return null;
      };

  /// Положительное количество (строго больше нуля).
  static Validator positive() => (value) {
        final n = int.tryParse((value ?? '').trim());
        if (n == null) return 'Введите целое число';
        return n <= 0 ? 'Значение должно быть больше нуля' : null;
      };

  /// Неотрицательное количество (ноль допустим).
  static Validator nonNegative() => (value) {
        final n = int.tryParse((value ?? '').trim());
        if (n == null) return 'Введите целое число';
        return n < 0 ? 'Значение не может быть отрицательным' : null;
      };

  static Validator email() => (value) =>
      _email.hasMatch((value ?? '').trim()) ? null : 'Неверный адрес почты, пример: name@mail.ru';

  static Validator phone() => (value) =>
      _phone.hasMatch((value ?? '').trim()) ? null : 'Формат: +7 и 10 цифр';

  static Validator personName() => (value) =>
      _name.hasMatch((value ?? '').trim()) ? null : 'Только буквы, дефис и пробел';

  static Validator digits(int count) => (value) =>
      RegExp('^\\d{$count}\$').hasMatch((value ?? '').trim()) ? null : 'Ровно $count цифр';

  static Validator pattern(RegExp re, String message) =>
      (value) => re.hasMatch((value ?? '').trim()) ? null : message;

  /// Дата ДД.ММ.ГГГГ, существующая и не позже сегодняшнего дня.
  static Validator pastDate() => (value) {
        final m = _date.firstMatch((value ?? '').trim());
        if (m == null) return 'Формат ДД.ММ.ГГГГ';
        final d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
        final date = DateTime(y, mo, d);
        if (date.day != d || date.month != mo) return 'Такой даты нет';
        if (date.isAfter(DateTime.now())) return 'Дата не может быть в будущем';
        if (y < 2000) return 'Не раньше 2000 года';
        return null;
      };

  /// Для выпадающих списков.
  static String? Function(T?) selected<T>(String message) =>
      (value) => value == null ? message : null;

  /// Для множественного выбора.
  static String? Function(List<int>?) atLeastOne(String message, {int? max}) => (value) {
        if (value == null || value.isEmpty) return message;
        if (max != null && value.length > max) return 'Не больше $max';
        return null;
      };
}
