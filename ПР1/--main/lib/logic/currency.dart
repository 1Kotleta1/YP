import 'format.dart';

/// Курсы к рублю (константы для учебного приложения).
const Map<String, double> currencyRatesToRub = {
  'RUB': 1.0,
  'USD': 92.50,
  'EUR': 100.20,
  'CNY': 12.80,
  'GBP': 117.40,
  'JPY': 0.62,
};

final List<String> currencyCodes = currencyRatesToRub.keys.toList();

sealed class ConvertResult {
  const ConvertResult();
}

class ConvertSuccess extends ConvertResult {
  final String from;
  final String to;
  final String formattedAmount;
  final String formattedResult;

  ConvertSuccess({
    required this.from,
    required this.to,
    required double amount,
    required double result,
  })  : formattedAmount = formatNumber(amount),
        formattedResult = formatNumber(result);
}

class ConvertFailure extends ConvertResult {
  final String message;
  const ConvertFailure(this.message);
}

ConvertResult convert({
  required String? from,
  required String? to,
  required String? rawAmount,
}) {
  if (from == null || to == null || rawAmount == null) {
    return const ConvertFailure(
      'В адресе не хватает параметров from, to или amount',
    );
  }
  if (!currencyRatesToRub.containsKey(from) ||
      !currencyRatesToRub.containsKey(to)) {
    return const ConvertFailure('Неизвестная валюта в адресе');
  }

  final amount = double.tryParse(rawAmount.replaceAll(',', '.'));
  if (amount == null) {
    return const ConvertFailure('Сумма в адресе не является числом');
  }
  if (amount < 0) {
    return const ConvertFailure('Сумма не может быть отрицательной');
  }

  final fromRate = currencyRatesToRub[from]!;
  final toRate = currencyRatesToRub[to]!;
  final inRub = amount * fromRate;
  final result = inRub / toRate;

  return ConvertSuccess(
    from: from,
    to: to,
    amount: amount,
    result: result,
  );
}
