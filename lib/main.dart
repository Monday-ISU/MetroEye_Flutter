import 'package:flutter/material.dart';
import 'package:metroeye_flutter/core/theme/app_theme.dart';
import 'ui/home/home_screen.dart';

void main() {
  runApp(const MetroEyeApp());
}

class MetroEyeApp extends StatelessWidget {
  const MetroEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MetroEye',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
