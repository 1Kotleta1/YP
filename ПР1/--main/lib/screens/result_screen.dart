import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logic/calculator.dart';
import '../logic/currency.dart';
import '../widgets/app_page.dart';
import '../widgets/home_nav_button.dart';

enum ResultKind { calculator, converter }

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.kind,
    required this.backPath,
    required this.query,
  });

  final ResultKind kind;
  final String backPath;
  final Map<String, String> query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (kind) {
      case ResultKind.calculator:
        return _buildCalculator(context, theme);
      case ResultKind.converter:
        return _buildConverter(context, theme);
    }
  }

  Widget _buildCalculator(BuildContext context, ThemeData theme) {
    final a = query['a'];
    final op = query['op'];
    final b = query['b'];
    final expression = '${a ?? '?'} ${op ?? '?'} ${b ?? '?'}';
    final result = calculate(a, op, b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат вычисления'),
        actions: const [HomeNavButton()],
      ),
      body: AppPage(
        child: _ResultBody(
          title: 'Выражение: $expression',
          success: result is CalcSuccess,
          message: result is CalcSuccess
              ? 'Ответ: ${result.formattedValue}'
              : (result as CalcFailure).message,
          onBack: () => context.go(backPath),
        ),
      ),
    );
  }

  Widget _buildConverter(BuildContext context, ThemeData theme) {
    final from = query['from'];
    final to = query['to'];
    final amount = query['amount'];
    final result = convert(from: from, to: to, rawAmount: amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат конвертации'),
        actions: const [HomeNavButton()],
      ),
      body: AppPage(
        child: _ResultBody(
          title: result is ConvertSuccess
              ? '${result.formattedAmount} ${result.from} → ${result.to}'
              : 'Конвертация',
          success: result is ConvertSuccess,
          message: result is ConvertSuccess
              ? 'Результат: ${result.formattedResult} ${result.to}'
              : (result as ConvertFailure).message,
          onBack: () => context.go(backPath),
        ),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.title,
    required this.success,
    required this.message,
    required this.onBack,
  });

  final String title;
  final bool success;
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Icon(
          success ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          size: 56,
          color: success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onBack,
          child: const Text('Вернуться к форме'),
        ),
      ],
    );
  }
}
