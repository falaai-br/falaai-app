import 'dart:async';

import 'package:falaai_app/app.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late Completer<FalaaiCore> opening;

  Future<void> pumpApp(WidgetTester tester) async {
    opening = Completer();
    final store = createStore(Dependencies(openCore: () => opening.future));
    store.dispatch(OpenCoreAction());
    await tester.pumpWidget(FalaAiApp(store: store));
  }

  testWidgets('mostra o progresso enquanto o core abre', (tester) async {
    await pumpApp(tester);

    expect(find.text('FalaAí'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Preparando suas conversas…'), findsOneWidget);
  });

  testWidgets('core aberto: lista de conversas vazia', (tester) async {
    await pumpApp(tester);

    opening.complete(FakeCore());
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
  });

  testWidgets('core não abriu: mensagem de erro em pt-BR', (tester) async {
    await pumpApp(tester);

    opening.completeError(StateError('chave errada'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível abrir suas conversas neste aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets('o app roda em pt-BR', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.text('FalaAí'));
    expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
  });
}
