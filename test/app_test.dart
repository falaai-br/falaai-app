import 'package:falaai_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('o app sobe com um Scaffold', (tester) async {
    await tester.pumpWidget(const FalaAiApp());

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
