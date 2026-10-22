// Roda em aparelho ou emulador conectado: make test-device. Fora dos hooks.
import 'package:falaai_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('o app sobe no aparelho', (tester) async {
    await tester.pumpWidget(const FalaAiApp());
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
