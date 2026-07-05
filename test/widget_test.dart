import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teenpatti_fresh/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const RecoverTeenPattiApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
