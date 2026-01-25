// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_manager/main.dart';

void main() {
  group('App Initialization Tests', () {
    testWidgets('App builds and renders the home screen without errors', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the root widget is present.
      expect(find.byType(MyApp), findsOneWidget);

      // Verify that the MaterialApp is configured.
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify that a Scaffold is present, indicating the UI is loaded.
      expect(find.byType(Scaffold), findsOneWidget);

      // Ensure no exceptions were thrown during the build process.
      expect(tester.takeException(), isNull);
    });
  });
}
