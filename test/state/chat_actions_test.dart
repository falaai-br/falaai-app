import 'dart:convert';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import 'package:falaai_app/chat/chat_store.dart';
import 'package:falaai_app/chat/typing.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/app_state.dart';
import 'package:falaai_app/state/chat_actions.dart';
import 'package:fake_async/fake_async.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const other = DeviceAddress(
    aci: '2c5e28ba-2fa1-11d2-883f-0016d3cca427',
    deviceId: 1,
  );
  var now = DateTime(2026, 10, 24, 9);

  late RecordingCore core;
  late MemoryChatStore chat;
  late FakeTypingSignals typing;
  late Dependencies deps;
  late Store<AppState> store;

  setUp(() async {
    now = DateTime(2026, 10, 24, 9);
    core = RecordingCore();
    chat = MemoryChatStore();
    typing = FakeTypingSignals();
    deps = testDependencies(
      openCore: () async => core,
      chat: chat,
      typing: typing,
      now: () => now,
    );
    store = createStore(deps);
    await store.dispatchAndWait(OpenCoreAction());
  });

  tearDown(() => deps.dispose());

  Future<void> start() => store.dispatchAndWait(StartChatAction());

  /// Deixa o stream entregar o evento e a action dele terminar.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await store.waitAllActions([], completeImmediately: true);
  }

  Future<void> receive(int id, DeviceAddress from, String text) async {
    core.deliveries.add(
      ChatEvent.messageReceived(
        id: id,
        from: from,
        body: Uint8List.fromList(utf8.encode(text)),
        identityChanged: false,
      ),
    );
    await settle();
  }

  group('StartChatAction', () {
    test('sem core aberto não faz nada', () async {
      final fresh = createStore(testDependencies(chat: chat));

      await fresh.dispatchAndWait(StartChatAction());

      expect(fresh.state.chat, const ChatState());
    });

    test('assina os eventos do core antes de ler as recebidas', () async {
      await start();

      expect(core.calls, ['events', 'receivedMessages']);
    });

    test(
      'traz as recebidas gravadas no core, em lotes, e monta a lista',
      () async {
        core.stored.addAll([
          for (var i = 1; i <= restoreBatchSize + 1; i++)
            receivedFrom(i.isEven ? other : testPeer, i, 'm$i'),
        ]);

        await start();

        expect(core.receivedQueries, [
          (after: 0, limit: restoreBatchSize),
          (after: restoreBatchSize, limit: restoreBatchSize),
        ]);
        final conversations = store.state.chat.conversations;
        expect(conversations.map((c) => c.id), [testPeer.aci, other.aci]);
        expect(conversations.first.last.body, 'm${restoreBatchSize + 1}');
        expect(conversations.first.unread, restoreBatchSize ~/ 2 + 1);
        expect(
          conversations.first.last.at,
          DateTime.fromMillisecondsSinceEpoch(1793782800000),
        );
      },
    );

    test('continua do último id gravado, sem duplicar', () async {
      core.stored.addAll([
        receivedFrom(testPeer, 1, 'a'),
        receivedFrom(testPeer, 2, 'b'),
      ]);
      await start();
      core.stored.add(receivedFrom(testPeer, 3, 'c'));
      core.receivedQueries.clear();

      await start();

      expect(core.receivedQueries.first.after, 2);
      final page = await chat.page(testPeer.aci, limit: 10);
      expect(page.messages.map((m) => m.body), ['a', 'b', 'c']);
    });
  });

  group('mensagem recebida pelo evento', () {
    test('entra na lista como não lida, com a hora de agora', () async {
      await start();

      await receive(1, testPeer, 'oi');

      final conversation = store.state.chat.conversations.single;
      expect(conversation.peer, testPeer);
      expect(conversation.last.body, 'oi');
      expect(conversation.last.at, now);
      expect(conversation.unread, 1);
      expect(store.state.chat.open, isNull);
    });

    test('na conversa aberta: entra na janela e já conta como lida', () async {
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

      await receive(1, testPeer, 'oi');

      expect(store.state.chat.open!.messages.map((m) => m.body), ['oi']);
      expect(store.state.chat.conversations.single.unread, 0);
    });

    test('de outra conversa: não entra na janela aberta', () async {
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

      await receive(1, other, 'olá');

      expect(store.state.chat.open!.messages, isEmpty);
      expect(store.state.chat.conversations.single.unread, 1);
    });

    test('a mesma mensagem pelo evento e pelo banco entra uma vez', () async {
      core.stored.add(receivedFrom(testPeer, 1, 'oi'));
      await start();

      await receive(1, testPeer, 'oi');

      final page = await chat.page(testPeer.aci, limit: 10);
      expect(page.messages, hasLength(1));
    });

    test('apaga o indicador de digitação do contato', () async {
      await start();
      store.dispatch(PeerTypingAction(testPeer.aci, typing: true));

      await receive(1, testPeer, 'oi');

      expect(store.state.chat.typing, isEmpty);
    });

    test('bytes inválidos não derrubam a conversa', () async {
      await start();
      core.deliveries.add(
        ChatEvent.messageReceived(
          id: 1,
          from: testPeer,
          body: Uint8List.fromList([0xff, 0xfe]),
          identityChanged: true,
        ),
      );
      await settle();

      final last = store.state.chat.conversations.single.last;
      expect(last.body, '\u{FFFD}\u{FFFD}');
      expect(last.identityChanged, isTrue);
    });
  });

  group('OpenConversationAction', () {
    test(
      'conversa nova: janela vazia com o primeiro dispositivo da conta',
      () async {
        await start();

        await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

        expect(
          store.state.chat.open,
          const OpenConversation(peer: testPeer, messages: [], hasOlder: false),
        );
      },
    );

    test(
      'conversa existente: a última página, lida, com o dispositivo conhecido',
      () async {
        const device2 = DeviceAddress(
          aci: '1b4e28ba-2fa1-11d2-883f-0016d3cca427',
          deviceId: 2,
        );
        core.stored.addAll([
          for (var i = 1; i <= messagePageSize + 3; i++)
            receivedFrom(device2, i, 'm$i'),
        ]);
        await start();

        await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

        final open = store.state.chat.open!;
        expect(open.peer, device2);
        expect(open.messages, hasLength(messagePageSize));
        expect(open.messages.first.body, 'm4');
        expect(open.messages.last.body, 'm${messagePageSize + 3}');
        expect(open.hasOlder, isTrue);
        expect(store.state.chat.conversations.single.unread, 0);
      },
    );

    test('CloseConversationAction fecha a janela', () async {
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

      await store.dispatchAndWait(CloseConversationAction());

      expect(store.state.chat.open, isNull);
    });
  });

  group('LoadOlderMessagesAction', () {
    test('acrescenta a página anterior no início da janela', () async {
      core.stored.addAll([
        for (var i = 1; i <= messagePageSize + 3; i++)
          receivedFrom(testPeer, i, 'm$i'),
      ]);
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

      await store.dispatchAndWait(LoadOlderMessagesAction());

      final open = store.state.chat.open!;
      expect(open.messages, hasLength(messagePageSize + 3));
      expect(open.messages.first.body, 'm1');
      expect(open.hasOlder, isFalse);
    });

    test('sem anteriores, ou sem conversa aberta, não muda nada', () async {
      await start();
      await store.dispatchAndWait(LoadOlderMessagesAction());
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));
      final before = store.state;

      await store.dispatchAndWait(LoadOlderMessagesAction());

      expect(store.state, before);
    });
  });

  group('SendMessageAction', () {
    test('põe na outbox do core e mostra como pendente', () async {
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

      await store.dispatchAndWait(SendMessageAction('  oi  '));

      expect(core.outbox.single.peer, testPeer);
      expect(utf8.decode(core.outbox.single.body), 'oi');
      final message = store.state.chat.open!.messages.single;
      expect(message.status, MessageStatus.pending);
      expect(message.body, 'oi');
      expect(message.clientMessageId, core.outbox.single.id);
      expect(store.state.chat.conversations.single.last, message);
      expect(store.state.chat.conversations.single.unread, 0);
    });

    test(
      'MessageSent marca enviada; MessageFailed marca a falha e o motivo',
      () async {
        await start();
        await store.dispatchAndWait(OpenConversationAction(testPeer.aci));
        await store.dispatchAndWait(SendMessageAction('a'));
        await store.dispatchAndWait(SendMessageAction('b'));
        final (a, b) = (core.outbox[0].id, core.outbox[1].id);

        core.deliveries.add(ChatEvent.messageSent(clientMessageId: a));
        core.deliveries.add(
          ChatEvent.messageFailed(
            clientMessageId: b,
            error: CoreError.sessionNotFound,
          ),
        );
        await settle();

        final messages = store.state.chat.open!.messages;
        expect(messages.map((m) => m.status), [
          MessageStatus.sent,
          MessageStatus.failed,
        ]);
        expect(messages[1].failure, CoreError.sessionNotFound);
        expect(
          store.state.chat.conversations.single.last.status,
          MessageStatus.failed,
        );
      },
    );

    test('evento de mensagem desconhecida não muda nada', () async {
      await start();
      final before = store.state;

      core.deliveries.add(
        ChatEvent.messageSent(clientMessageId: Uint8List(16)),
      );
      await settle();

      expect(store.state, before);
    });

    test('core recusou na hora: a mensagem aparece como falha', () async {
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));
      core.outboxErrors.add(CoreError.noAccount);

      await store.dispatchAndWait(SendMessageAction('oi'));

      final message = store.state.chat.open!.messages.single;
      expect(message.status, MessageStatus.failed);
      expect(message.failure, CoreError.noAccount);
      expect(message.clientMessageId, isNull);
    });

    test('texto vazio ou sem conversa aberta: nada sai', () async {
      await start();
      await store.dispatchAndWait(SendMessageAction('oi'));
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

      await store.dispatchAndWait(SendMessageAction('   '));

      expect(core.outbox, isEmpty);
      expect(store.state.chat.open!.messages, isEmpty);
    });

    test('enviar avisa que parou de digitar', () async {
      await start();
      await store.dispatchAndWait(OpenConversationAction(testPeer.aci));
      await store.dispatchAndWait(ComposerTypingAction(typing: true));

      await store.dispatchAndWait(SendMessageAction('oi'));

      expect(typing.sent, [
        (peer: testPeer, typing: true),
        (peer: testPeer, typing: false),
      ]);
    });
  });

  group('digitação', () {
    test('aviso do contato acende e apaga o indicador', () async {
      await start();

      typing.events.add(const TypingEvent(from: testPeer, typing: true));
      await settle();
      expect(store.state.chat.typing, {testPeer.aci});

      typing.events.add(const TypingEvent(from: testPeer, typing: false));
      await settle();
      expect(store.state.chat.typing, isEmpty);
    });

    test('o indicador some sozinho depois de typingTimeout', () {
      fakeAsync((async) {
        store.dispatch(PeerTypingAction(testPeer.aci, typing: true));
        async.elapse(typingTimeout - const Duration(seconds: 1));
        expect(store.state.chat.typing, {testPeer.aci});

        store.dispatch(PeerTypingAction(testPeer.aci, typing: true));
        async.elapse(typingTimeout - const Duration(seconds: 1));
        expect(store.state.chat.typing, {
          testPeer.aci,
        }, reason: 'aviso novo renova');

        async.elapse(const Duration(seconds: 1));
        expect(store.state.chat.typing, isEmpty);
      });
    });

    test(
      'o compositor avisa no máximo a cada typingRefresh, e "parou" uma vez',
      () async {
        await start();
        await store.dispatchAndWait(OpenConversationAction(testPeer.aci));

        await store.dispatchAndWait(ComposerTypingAction(typing: true));
        now = now.add(const Duration(seconds: 1));
        await store.dispatchAndWait(ComposerTypingAction(typing: true));
        now = now.add(typingRefresh);
        await store.dispatchAndWait(ComposerTypingAction(typing: true));
        await store.dispatchAndWait(ComposerTypingAction(typing: false));
        await store.dispatchAndWait(ComposerTypingAction(typing: false));

        expect(typing.sent, [
          (peer: testPeer, typing: true),
          (peer: testPeer, typing: true),
          (peer: testPeer, typing: false),
        ]);
      },
    );

    test('sem conversa aberta o compositor não avisa', () async {
      await start();

      await store.dispatchAndWait(ComposerTypingAction(typing: true));

      expect(typing.sent, isEmpty);
    });
  });
}
