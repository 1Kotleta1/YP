import 'format.dart';

/// Результат вычисления: либо значение, либо описание ошибки.
sealed class CalcResult {
  const CalcResult();
}

class CalcSuccess extends CalcResult {
  final String formattedValue;

  CalcSuccess(double value) : formattedValue = formatNumber(value);
}

class CalcFailure extends CalcResult {
  final String message;
  const CalcFailure(this.message);
}

const _allowedOps = {'+', '-', '*', '/'};

CalcResult calculate(String? rawA, String? rawOp, String? rawB) {
  if (rawA == null || rawOp == null || rawB == null) {
    return const CalcFailure('В адресе не хватает параметров a, op или b');
  }
  if (!_allowedOps.contains(rawOp)) {
    return const CalcFailure('Неизвестная операция');
  }

  final a = double.tryParse(rawA.replaceAll(',', '.'));
  final b = double.tryParse(rawB.replaceAll(',', '.'));
  if (a == null || b == null) {
    return const CalcFailure('В адресе переданы не числа');
  }

  return switch (rawOp) {
    '+' => CalcSuccess(a + b),
    '-' => CalcSuccess(a - b),
    '*' => CalcSuccess(a * b),
    '/' => b == 0
        ? const CalcFailure('Деление на ноль невозможно')
        : CalcSuccess(a / b),
    _ => const CalcFailure('Неизвестная операция'),
  };
}
