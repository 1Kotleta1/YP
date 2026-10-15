import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logic/currency.dart';
import '../services/preferences_service.dart';
import '../theme_controller.dart';
import '../widgets/app_page.dart';
import '../widgets/home_nav_button.dart';
import '../widgets/theme_toggle_button.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({
    super.key,
    required this.themeController,
    required this.prefs,
  });

  final ThemeController themeController;
  final PreferencesService prefs;

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _from = 'USD';
  String _to = 'RUB';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPair();
  }

  Future<void> _loadPair() async {
    final pair = await widget.prefs.loadConverterPair();
    final valid = pair != null &&
        currencyRatesToRub.containsKey(pair.$1) &&
        currencyRatesToRub.containsKey(pair.$2);
    if (valid && mounted) {
      setState(() {
        _from = pair.$1;
        _to = pair.$2;
        _loaded = true;
      });
    } else if (mounted) {
      setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _amountValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите сумму';
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Это не число';
    }
    if (parsed < 0) {
      return 'Сумма не может быть отрицательной';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.prefs.saveConverterPair(_from, _to);
    if (!mounted) return;
    final amount = Uri.encodeComponent(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final from = Uri.encodeComponent(_from);
    final to = Uri.encodeComponent(_to);
    context.go('/converter/result?from=$from&to=$to&amount=$amount');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Конвертер валют'),
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
              DropdownButtonFormField<String>(
                initialValue: _from,
                decoration: const InputDecoration(
                  labelText: 'Из валюты',
                  border: OutlineInputBorder(),
                ),
                items: currencyCodes
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _from = value ?? _from),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _to,
                decoration: const InputDecoration(
                  labelText: 'В валюту',
                  border: OutlineInputBorder(),
                ),
                items: currencyCodes
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _to = value ?? _to),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _amountValidator,
              ),
              const SizedBox(height: 8),
              Text(
                'Курсы заданы константами относительно рубля (учебный пример).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Конвертировать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
