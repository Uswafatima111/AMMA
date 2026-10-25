import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';

void main() {
  runApp(const AmmaApp());
}

class AmmaApp extends StatelessWidget {
  const AmmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AMMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // TEMPORARILY OPEN ASHA DASHBOARD DIRECTLY
      initialRoute: AppRoutes.login,

      routes: AppRoutes.routes,
    );
  }
}