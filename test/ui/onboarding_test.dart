import 'dart:async';
import 'dart:convert';

import 'package:falaai_app/account/account_store.dart';
import 'package:falaai_app/account/accounts_api.dart';
import 'package:falaai_app/account/pin.dart';
import 'package:falaai_app/app.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/onboarding_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 9);

  late MemorySecretStore secrets;
  late FakeAccountsApi api;

  setUp(() {
    secrets = MemorySecretStore();
    api = FakeAccountsApi();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final store = createStore(
      testDependencies(secrets: secrets, accounts: api, now: () => now),
    );
    store.dispatch(OpenCoreAction());
    store.dispatch(LoadAccountAction());
    await tester.pumpWidget(FalaAiApp(store: store));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> enterPhone(WidgetTester tester, String phone) async {
    await tester.enterText(field('Celular com DDD'), phone);
    await tap(tester, 'Continuar');
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(field('Código de 6 dígitos'), code);
    await tester.pump();
    await tap(tester, 'Confirmar');
  }

  Future<void> enterPin(WidgetTester tester, String pin, String again) async {
    await tester.enterText(field('PIN (pelo menos 4 números)'), pin);
    await tester.enterText(field('Repita o PIN'), again);
    await tester.pump();
  }

  FilledButton button(WidgetTester tester, String text) =>
      tester.widget(find.widgetWithText(FilledButton, text));

  testWidgets('número, código, nome e PIN levam à lista de conversas', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(
      find.text('Só você e quem recebe podem ler suas mensagens.'),
      findsOneWidget,
    );

    await enterPhone(tester, '(11) 91234-5678');
    expect(
      find.text('Enviamos um código por SMS para (11) 91234-5678.'),
      findsOneWidget,
    );

    await enterCode(tester, '123456');
    expect(api.registrations.single, (phone: '+5511912345678', code: '123456'));
    expect(find.text('Como você quer ser chamado?'), findsOneWidget);

    await tester.enterText(field('Seu nome'), 'Ana');
    await tester.pump();
    await tap(tester, 'Continuar');
    expect(find.text('Crie um PIN'), findsOneWidget);

    await enterPin(tester, '2468', '2468');
    await tap(tester, 'Criar PIN');

    expect(api.pins.single.pin, '2468');
    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
    expect(find.text('Crie um PIN para proteger sua conta.'), findsNothing);
  });

  testWidgets('número que não é celular do Brasil mostra o erro', (
    tester,
  ) async {
    await pumpApp(tester);

    await enterPhone(tester, '1132345678');

    expect(find.text('Digite um celular do Brasil com DDD.'), findsOneWidget);
    expect(find.text('Qual é o seu celular?'), findsOneWidget);
  });

  testWidgets('código errado mostra o erro; mudar número volta', (
    tester,
  ) async {
    await pumpApp(tester);
    await enterPhone(tester, '11912345678');
    api.registerErrors.add(AccountsError.invalidCode);

    await enterCode(tester, '000000');

    expect(
      find.text('Código incorreto. Confira o SMS e tente de novo.'),
      findsOneWidget,
    );
    await tap(tester, 'Mudar número');
    expect(find.text('Qual é o seu celular?'), findsOneWidget);
  });

  testWidgets('confirmar só com o código completo; espera o servidor', (
    tester,
  ) async {
    await pumpApp(tester);
    await enterPhone(tester, '11912345678');

    await tester.enterText(field('Código de 6 dígitos'), '123');
    await tester.pump();
    expect(button(tester, 'Confirmar').onPressed, isNull);

    api.registerGate = Completer();
    await tester.enterText(field('Código de 6 dígitos'), '123456');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(find.bySemanticsLabel('Aguarde…'), findsOneWidget);

    api.registerGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Como você quer ser chamado?'), findsOneWidget);
  });

  testWidgets('PINs diferentes: avisa e não deixa criar', (tester) async {
    secrets.values[AccountStore.deviceName] = jsonEncode(testDevice.toJson());
    secrets.values[AccountStore.profileNameName] = 'Ana';
    await pumpApp(tester);

    await enterPin(tester, '2468', '2469');

    expect(find.text('Os PINs não são iguais.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Criar PIN'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Criar PIN'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(create.onPressed, isNull);
  });

  testWidgets('PIN sem rota no servidor: explica e deixa adiar', (
    tester,
  ) async {
    secrets.values[AccountStore.deviceName] = jsonEncode(testDevice.toJson());
    secrets.values[AccountStore.profileNameName] = 'Ana';
    api.pinErrors.add(AccountsError.unavailable);
    await pumpApp(tester);

    await enterPin(tester, '2468', '2468');
    await tap(tester, 'Criar PIN');

    expect(
      find.text('Não foi possível criar o PIN agora. Tente mais tarde.'),
      findsOneWidget,
    );
    await tap(tester, 'Agora não');
    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
  });

  testWidgets('PIN adiado: lista sem lembrete até a hora de lembrar', (
    tester,
  ) async {
    secrets.values[AccountStore.deviceName] = jsonEncode(testDevice.toJson());
    secrets.values[AccountStore.profileNameName] = 'Ana';
    await pumpApp(tester);

    await tap(tester, 'Agora não');

    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
    expect(find.text('Crie um PIN para proteger sua conta.'), findsNothing);
    final stored = await AccountStore(secrets).load();
    expect(stored.pin, PinStatus.deferred);
  });

  testWidgets('lembrete do PIN leva à tela do PIN e some depois de criado', (
    tester,
  ) async {
    secrets.values[AccountStore.deviceName] = jsonEncode(testDevice.toJson());
    secrets.values[AccountStore.profileNameName] = 'Ana';
    await AccountStore(secrets).savePin(PinStatus.deferred, remindAt: now);
    await pumpApp(tester);
    expect(find.text('Crie um PIN para proteger sua conta.'), findsOneWidget);

    await tap(tester, 'Criar PIN');
    await enterPin(tester, '13579', '13579');
    await tap(tester, 'Criar PIN');

    expect(api.pins.single.pin, '13579');
    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
    expect(find.text('Crie um PIN para proteger sua conta.'), findsNothing);
  });

  testWidgets('lembrete do PIN adiado de novo some', (tester) async {
    secrets.values[AccountStore.deviceName] = jsonEncode(testDevice.toJson());
    secrets.values[AccountStore.profileNameName] = 'Ana';
    await AccountStore(secrets).savePin(PinStatus.deferred, remindAt: now);
    await pumpApp(tester);

    await tap(tester, 'Agora não');

    expect(find.text('Crie um PIN para proteger sua conta.'), findsNothing);
    final stored = await AccountStore(secrets).load();
    expect(
      stored.pinRemindAt?.isAtSameMomentAs(now.add(pinReminderInterval)),
      isTrue,
    );
  });
}
