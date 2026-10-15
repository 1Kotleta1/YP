import 'package:calc_web/logic/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('convert', () {
    test('конвертирует USD в RUB', () {
      final r = convert(from: 'USD', to: 'RUB', rawAmount: '10');
      expect(r, isA<ConvertSuccess>());
      final s = r as ConvertSuccess;
      expect(s.formattedResult, '925');
    });

    test('отклоняет неизвестную валюту', () {
      final r = convert(from: 'XXX', to: 'RUB', rawAmount: '1');
      expect(r, isA<ConvertFailure>());
    });
  });
}
