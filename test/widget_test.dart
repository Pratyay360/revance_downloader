// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revance_downloader/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Trigger a frame to start building the widget tree
    await tester.pump();

    // Verify that our app builds without errors
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify that the home page is present
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
