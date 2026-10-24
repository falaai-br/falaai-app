import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:falaai_app/account/account_store.dart';
import 'package:falaai_app/app.dart';
import 'package:falaai_app/chat/chat_store.dart';
import 'package:falaai_app/chat/typing.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/app_state.dart';
import 'package:falaai_app/state/chat_actions.dart';
import 'package:falaai_app/state/onboarding_actions.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const other = DeviceAddress(
    aci: '2c5e28ba-2fa1-11d2-883f-0016d3cca427',
    deviceId: 1,
  );
  final today = DateTime.now();
  final at9 = DateTime(today.year, today.month, today.day, 9, 5);

  late RecordingCore core;
  late MemoryChatStore chat;
  late FakeTypingSignals typing;
  late Dependencies deps;
  late Store<AppState> store;

  setUp(() {
    core = RecordingCore();
    chat = MemoryChatStore();
    typing = FakeTypingSignals();
    deps = testDependencies(
      openCore: () async => core,
      chat: chat,
      typing: typing,
      now: () => at9,
      secrets: MemorySecretStore()
        ..values[AccountStore.deviceName] = jsonEncode(testDevice.toJson())
        ..values[AccountStore.profileNameName] = 'Ana'
        ..values[AccountStore.pinName] = jsonEncode({'status': 'set'}),
    );
    store = createStore(deps);
  });

  tearDown(() => deps.dispose());

  /// Abre o app já registrado, com o core aberto e as conversas carregadas.
  Future<void> pumpApp(WidgetTester tester) async {
    await store.dispatchAndWait(OpenCoreAction());
    await store.dispatchAndWait(LoadAccountAction());
    await store.dispatchAndWait(StartChatAction());
    await tester.pumpWidget(FalaAiApp(store: store));
    await tester.pumpAndSettle();
  }

  Future<void> receive(
    WidgetTester tester,
    int id,
    DeviceAddress from,
    String text,
  ) async {
    core.deliveries.add(
      ChatEvent.messageReceived(
        id: id,
        from: from,
        body: utf8.encode(text),
        identityChanged: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openChat(WidgetTester tester, String aci) async {
    await tester.tap(find.text('Contato ${aci.substring(0, 8)}'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.widgetWithText(TextField, 'Mensagem'), text);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  group('lista de conversas', () {
    testWidgets('vazia: convite e botão de nova conversa', (tester) async {
      await pumpApp(tester);

      expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
      expect(find.text('Nova conversa'), findsOneWidget);
    });

    testWidgets(
      'mostra contato, prévia, hora e não lidas; a mais recente primeiro',
      (tester) async {
        core.stored.addAll([
          receivedFrom(
            testPeer,
            1,
            'oi',
            serverTimestamp: at9.millisecondsSinceEpoch,
          ),
          receivedFrom(
            testPeer,
            2,
            'tudo bem?',
            serverTimestamp: at9.millisecondsSinceEpoch,
          ),
          receivedFrom(
            other,
            3,
            'olá',
            serverTimestamp: DateTime(2025, 12, 31, 8).millisecondsSinceEpoch,
          ),
        ]);
        await pumpApp(tester);

        final tiles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .toList();
        expect(tiles, hasLength(2));
        expect(find.text('Contato 2c5e28ba'), findsOneWidget);
        expect(find.text('Contato 1b4e28ba'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Contato 2c5e28ba')).dy,
          lessThan(tester.getTopLeft(find.text('Contato 1b4e28ba')).dy),
          reason: 'o maior id é a mensagem mais recente',
        );
        expect(find.text('tudo bem?'), findsOneWidget);
        expect(find.text('olá'), findsOneWidget);
        expect(find.text('09:05'), findsOneWidget);
        expect(find.text('31/12/2025'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('2 mensagens não lidas')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('1 mensagem não lida')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'mensagem nova entra na lista; sua última aparece como "Você:"',
      (tester) async {
        await pumpApp(tester);

        await receive(tester, 1, testPeer, 'oi');
        expect(find.text('oi'), findsOneWidget);

        await openChat(tester, testPeer.aci);
        await type(tester, 'olá!');
        await send(tester);
        await back(tester);

        expect(find.text('Você: olá!'), findsOneWidget);
        expect(find.byType(Badge), findsNothing, reason: 'lida ao abrir');
      },
    );

    testWidgets('contato digitando troca a prévia', (tester) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');

      typing.events.add(const TypingEvent(from: testPeer, typing: true));
      await tester.pumpAndSettle();
      expect(find.text('digitando…'), findsOneWidget);

      await tester.pump(typingTimeout);
      await tester.pumpAndSettle();
      expect(find.text('digitando…'), findsNothing);
      expect(find.text('oi'), findsOneWidget);
    });

    testWidgets('nova conversa pede o id da conta e abre o chat', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Nova conversa'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'ID da conta'),
        'ana',
      );
      await tester.tap(find.text('Conversar'));
      await tester.pumpAndSettle();
      expect(find.text('Isso não é um ID de conta.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'ID da conta'),
        ' ${testPeer.aci.toUpperCase()} ',
      );
      await tester.tap(find.text('Conversar'));
      await tester.pumpAndSettle();

      expect(find.text('Contato 1b4e28ba'), findsOneWidget);
      expect(
        find.text('Nenhuma mensagem ainda. Só você e quem recebe podem ler.'),
        findsOneWidget,
      );
      expect(store.state.chat.open?.peer, testPeer);
    });
  });

  group('tela de chat', () {
    testWidgets('mostra as mensagens, envia e acompanha os recibos', (
      tester,
    ) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');
      await openChat(tester, testPeer.aci);

      expect(find.text('oi'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^09:05')), findsOneWidget);
      final sendButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.send),
          matching: find.byType(IconButton),
        ),
      );
      expect(sendButton.onPressed, isNull, reason: 'sem texto não envia');

      await type(tester, 'olá!');
      await send(tester);
      expect(find.text('olá!'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Você, 09:05, Enviando')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Mensagem'))
            .controller
            ?.text,
        isEmpty,
      );

      core.deliveries.add(
        ChatEvent.messageSent(clientMessageId: core.outbox.single.id),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('Você, 09:05, Enviada')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('envio recusado mostra o motivo', (tester) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');
      await openChat(tester, testPeer.aci);
      await type(tester, 'olá!');
      await send(tester);

      core.deliveries.add(
        ChatEvent.messageFailed(
          clientMessageId: core.outbox.single.id,
          error: CoreError.sessionNotFound,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Não foi enviada')), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.text('Ainda não há uma conversa segura com esta pessoa.'),
        findsOneWidget,
      );
    });

    testWidgets('recibos de entrega e leitura', (tester) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');
      await openChat(tester, testPeer.aci);
      await type(tester, 'a');
      await send(tester);
      await type(tester, 'b');
      await send(tester);
      await chat.setStatus(core.outbox[0].id, MessageStatus.delivered);
      await chat.setStatus(core.outbox[1].id, MessageStatus.read);
      // A tela relê a janela ao abrir.
      await back(tester);
      await openChat(tester, testPeer.aci);

      expect(find.bySemanticsLabel(RegExp('Entregue')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Lida')), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNWidgets(2));
    });

    testWidgets('aviso de código de segurança na mensagem em que mudou', (
      tester,
    ) async {
      core.stored.add(receivedFrom(testPeer, 1, 'oi', identityChanged: true));
      await pumpApp(tester);
      await openChat(tester, testPeer.aci);

      expect(
        find.text('O código de segurança desta conversa mudou.'),
        findsOneWidget,
      );
    });

    testWidgets('rolar até o início traz a página anterior', (tester) async {
      core.stored.addAll([
        for (var i = 1; i <= messagePageSize + 5; i++)
          receivedFrom(testPeer, i, 'm$i'),
      ]);
      await pumpApp(tester);
      await openChat(tester, testPeer.aci);

      expect(store.state.chat.open!.messages, hasLength(messagePageSize));
      expect(find.text('m${messagePageSize + 5}'), findsOneWidget);
      expect(find.text('m6'), findsNothing, reason: 'fora da janela');

      // Rola para cima (lista invertida: deslocamento positivo) até o carregador aparecer.
      await tester.fling(find.byType(ListView), const Offset(0, 6000), 8000);
      await tester.pumpAndSettle();

      expect(store.state.chat.open!.messages, hasLength(messagePageSize + 5));
      expect(store.state.chat.open!.hasOlder, isFalse);
      expect(
        find.bySemanticsLabel('Carregando mensagens anteriores…'),
        findsNothing,
      );
    });

    testWidgets('indicador de digitação do contato', (tester) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');
      await openChat(tester, testPeer.aci);

      typing.events.add(const TypingEvent(from: testPeer, typing: true));
      await tester.pumpAndSettle();
      expect(find.text('Contato 1b4e28ba está digitando…'), findsOneWidget);

      await receive(tester, 2, testPeer, 'tudo bem?');
      expect(find.text('Contato 1b4e28ba está digitando…'), findsNothing);
      expect(find.text('tudo bem?'), findsOneWidget);
    });

    testWidgets('escrever avisa que está digitando; parar, que parou', (
      tester,
    ) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');
      await openChat(tester, testPeer.aci);

      await type(tester, 'ol');
      await type(tester, 'olá');
      expect(typing.sent, [(peer: testPeer, typing: true)]);

      await tester.pump(typingTimeout);
      expect(typing.sent.last, (peer: testPeer, typing: false));

      await type(tester, '');
      await tester.pump();
      expect(typing.sent, hasLength(2), reason: 'já tinha parado');
    });

    testWidgets('sair da tela fecha a conversa', (tester) async {
      await pumpApp(tester);
      await receive(tester, 1, testPeer, 'oi');
      await openChat(tester, testPeer.aci);
      expect(store.state.chat.open, isNotNull);

      await back(tester);

      expect(store.state.chat.open, isNull);
    });
  });
}
