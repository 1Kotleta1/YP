import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme_controller.dart';
import '../widgets/app_page.dart';
import '../widgets/home_nav_button.dart';
import '../widgets/theme_toggle_button.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aController = TextEditingController();
  final _bController = TextEditingController();
  String _operation = '+';

  static const _operations = ['+', '-', '*', '/'];

  @override
  void dispose() {
    _aController.dispose();
    _bController.dispose();
    super.dispose();
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите число';
    }
    if (double.tryParse(value.replaceAll(',', '.')) == null) {
      return 'Это не число';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final a = Uri.encodeComponent(
      _aController.text.trim().replaceAll(',', '.'),
    );
    final b = Uri.encodeComponent(
      _bController.text.trim().replaceAll(',', '.'),
    );
    final op = Uri.encodeComponent(_operation);
    context.go('/calculator/result?a=$a&op=$op&b=$b');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор'),
        actions: [
          const HomeNavButton(),
          ThemeToggleButton(controller: widget.themeController),
        ],
      ),
      body: AppPage(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _aController,
                decoration: const InputDecoration(
                  labelText: 'Первое число',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _operation,
                decoration: const InputDecoration(
                  labelText: 'Операция',
                  border: OutlineInputBorder(),
                ),
                items: _operations
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _operation = value ?? '+'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bController,
                decoration: const InputDecoration(
                  labelText: 'Второе число',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Вычислить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
