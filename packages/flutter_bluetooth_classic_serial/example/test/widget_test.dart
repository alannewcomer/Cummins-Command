// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Bluetooth Classic app loads correctly', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app loads with the correct title
    expect(find.text('Bluetooth Classic Serial'), findsOneWidget);

    // Since Bluetooth functionality requires platform channels, we'll just verify
    // the basic UI elements are present
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    // The actual content depends on Bluetooth availability, which we can't test
    // in unit tests without mocking the platform channels
  });

  testWidgets('App has refresh button in app bar', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Look for the refresh button in the app bar
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
