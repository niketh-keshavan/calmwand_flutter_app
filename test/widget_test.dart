// Basic Flutter widget test for Calmwand app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calmwand_flutter_app/main.dart';

void main() {
  testWidgets('CalmwandApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CalmwandApp());

    // Verify that the app builds without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
