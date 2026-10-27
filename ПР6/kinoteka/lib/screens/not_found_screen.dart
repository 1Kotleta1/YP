import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Страница не найдена')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text('Адрес не найден', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(location),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.go('/movies'), child: const Text('К списку фильмов')),
          ],
        ),
      ),
    );
  }
}
