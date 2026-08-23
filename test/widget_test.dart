import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/main.dart';

void main() {
  testWidgets('Navigation bar contains Pengaturan tab test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Pengaturan'), findsAtLeastNWidgets(1));
  });
}
