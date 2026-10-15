import 'package:flutter/material.dart';

import '../theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = controller.mode == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
      onPressed: controller.toggleLightDark,
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
    );
  }
}
