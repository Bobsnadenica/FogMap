import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/app_shell.dart';

class FogFrontierApp extends StatelessWidget {
  const FogFrontierApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FogFrontier',
      theme: AppTheme.darkFantasy,
      home: AppShell(controller: controller),
    );
  }
}