import 'package:calc_web/logic/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculate', () {
    test('складывает числа', () {
      final r = calculate('2', '+', '3');
      expect(r, isA<CalcSuccess>());
      expect((r as CalcSuccess).formattedValue, '5');
    });

    test('делит с округлением', () {
      final r = calculate('10', '/', '3');
      expect(r, isA<CalcSuccess>());
      expect((r as CalcSuccess).formattedValue, '3.33333333');
    });

    test('деление на ноль', () {
      final r = calculate('1', '/', '0');
      expect(r, isA<CalcFailure>());
      expect((r as CalcFailure).message, contains('ноль'));
    });

    test('нечисловой ввод', () {
      final r = calculate('abc', '+', '1');
      expect(r, isA<CalcFailure>());
    });

    test('неизвестная операция', () {
      final r = calculate('1', '%', '2');
      expect(r, isA<CalcFailure>());
    });

    test('отсутствуют параметры', () {
      final r = calculate(null, '+', '1');
      expect(r, isA<CalcFailure>());
    });
  });
}
