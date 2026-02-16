import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'src/app.dart';

void main() {
  AppTheme.configureOrientation();
  runApp(const App());
}
