import 'dart:async';
import 'dart:convert';

import 'package:falaai_app/account/account_store.dart';
import 'package:falaai_app/app.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/onboarding_actions.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late Completer<FalaaiCore> opening;

  /// Aparelho já registrado, com nome e PIN criado.
  MemorySecretStore registered() => MemorySecretStore()
    ..values[AccountStore.deviceName] = jsonEncode(testDevice.toJson())
    ..values[AccountStore.profileNameName] = 'Ana'
    ..values[AccountStore.pinName] = jsonEncode({'status': 'set'});

  Future<void> pumpApp(WidgetTester tester, MemorySecretStore secrets) async {
    opening = Completer();
    final store = createStore(
      testDependencies(openCore: () => opening.future, secrets: secrets),
    );
    store.dispatch(OpenCoreAction());
    store.dispatch(LoadAccountAction());
    await tester.pumpWidget(FalaAiApp(store: store));
  }

  testWidgets('mostra o progresso enquanto o core abre', (tester) async {
    await pumpApp(tester, registered());

    expect(find.text('FalaAí'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Preparando suas conversas…'), findsOneWidget);
  });

  testWidgets('aparelho registrado: lista de conversas vazia', (tester) async {
    await pumpApp(tester, registered());

    opening.complete(FakeCore());
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
  });

  testWidgets('aparelho sem registro: abre no cadastro', (tester) async {
    await pumpApp(tester, MemorySecretStore());

    opening.complete(FakeCore());
    await tester.pumpAndSettle();

    expect(find.text('Qual é o seu celular?'), findsOneWidget);
  });

  testWidgets('core não abriu: mensagem de erro em pt-BR', (tester) async {
    await pumpApp(tester, registered());

    opening.completeError(StateError('chave errada'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível abrir suas conversas neste aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets('o app roda em pt-BR', (tester) async {
    await pumpApp(tester, registered());

    final context = tester.element(find.text('FalaAí'));
    expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
  });
}
