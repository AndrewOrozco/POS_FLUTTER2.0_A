// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:mis_proyectos_flutter/src/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
  });
}