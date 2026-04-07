import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cargar configuración desde .env antes de iniciar la app
  await dotenv.load(fileName: '.env');
  AppTheme.configureOrientation();
  runApp(const App());
}
