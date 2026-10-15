import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Переход на главную (context.go не кладёт экраны в стек Navigator).
class HomeNavButton extends StatelessWidget {
  const HomeNavButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'На главную',
      icon: const Icon(Icons.home_outlined),
      onPressed: () => context.go('/'),
    );
  }
}
