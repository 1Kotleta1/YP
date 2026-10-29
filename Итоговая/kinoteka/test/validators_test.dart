import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/validation/validators.dart';

void main() {
  test('обязательность и длина', () {
    final v = Validators.all([Validators.required(), Validators.maxLength(5)]);
    expect(v(''), 'Обязательное поле');
    expect(v('   '), 'Обязательное поле');
    expect(v('Длинный текст'), 'Не длиннее 5 символов');
    expect(v('Сталк'), isNull);
  });

  test('диапазон чисел и положительность', () {
    expect(Validators.intRange(1895, 2030)('1800'), 'Допустимо от 1895 до 2030');
    expect(Validators.intRange(1895, 2030)('abc'), 'Введите целое число');
    expect(Validators.doubleRange(0, 10)('8,7'), isNull);
    expect(Validators.positive()('0'), 'Значение должно быть больше нуля');
    expect(Validators.nonNegative()('-1'), 'Значение не может быть отрицательным');
  });

  test('формат почты и телефона', () {
    expect(Validators.email()('name@mail.ru'), isNull);
    expect(Validators.email()('name@mail'), isNotNull);
    expect(Validators.email()('без собаки.ru'), isNotNull);
    expect(Validators.phone()('+79161234567'), isNull);
    expect(Validators.optional(Validators.phone())(''), isNull);
    expect(Validators.phone()('89161234567'), 'Формат: +7 и 10 цифр');
  });

  test('номер удостоверения и дата выдачи', () {
    expect(Validators.digits(9)('121000001'), isNull);
    expect(Validators.digits(9)('12100'), 'Ровно 9 цифр');
    expect(Validators.pastDate()('31.02.2026'), 'Такой даты нет');
    expect(Validators.pastDate()('01.01.2099'), 'Дата не может быть в будущем');
    expect(Validators.pastDate()('2026-01-01'), 'Формат ДД.ММ.ГГГГ');
  });

  test('множественный выбор', () {
    final v = Validators.atLeastOne('Выберите жанр', max: 2);
    expect(v([]), 'Выберите жанр');
    expect(v([1, 2, 3]), 'Не больше 2');
    expect(v([1]), isNull);
  });
}
