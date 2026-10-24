import 'dart:typed_data';

import 'package:falaai_app/chat/chat_store.dart';
import 'package:falaai_app/chat/message.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const other = DeviceAddress(
    aci: '2c5e28ba-2fa1-11d2-883f-0016d3cca427',
    deviceId: 2,
  );
  final at = DateTime(2026, 10, 24, 9);

  Message received(DeviceAddress from, String body, {int? coreId}) => Message(
    id: 0,
    peer: from,
    body: body,
    at: at,
    status: MessageStatus.received,
    coreId: coreId,
  );

  Message outgoing(DeviceAddress to, String body, int clientId) => Message(
    id: 0,
    peer: to,
    body: body,
    at: at,
    status: MessageStatus.pending,
    clientMessageId: Uint8List(16)..fillRange(0, 16, clientId),
  );

  late MemoryChatStore store;

  setUp(() => store = MemoryChatStore());

  group('add', () {
    test('atribui ids crescentes na ordem de gravação', () async {
      final first = await store.add(received(testPeer, 'a'));
      final second = await store.add(outgoing(testPeer, 'b', 1));

      expect([first.id, second.id], [1, 2]);
      expect(first.body, 'a');
    });

    test(
      'recebida com coreId já gravado volta como está, sem duplicar',
      () async {
        final stored = await store.add(received(testPeer, 'a', coreId: 7));

        final again = await store.add(received(testPeer, 'a', coreId: 7));

        expect(again, stored);
        final page = await store.page(testPeer.aci, limit: 10);
        expect(page.messages, [stored]);
        final conversation = (await store.conversations()).single;
        expect(conversation.unread, 1, reason: 'a duplicata não conta');
      },
    );

    test('lastCoreId é o maior coreId gravado', () async {
      expect(await store.lastCoreId(), 0);
      await store.add(received(testPeer, 'a', coreId: 3));
      await store.add(received(other, 'b', coreId: 9));
      await store.add(received(testPeer, 'c', coreId: 5));

      expect(await store.lastCoreId(), 9);
    });
  });

  group('page', () {
    test('conversa vazia', () async {
      expect(await store.page(testPeer.aci, limit: 10), MessagePage.empty);
    });

    test('sem cursor traz as mais novas, da mais antiga à mais nova', () async {
      for (var i = 1; i <= 5; i++) {
        await store.add(received(testPeer, 'm$i'));
      }

      final page = await store.page(testPeer.aci, limit: 2);

      expect(page.messages.map((m) => m.body), ['m4', 'm5']);
      expect(page.hasOlder, isTrue);
    });

    test('com cursor traz as anteriores ao id, até acabar', () async {
      for (var i = 1; i <= 5; i++) {
        await store.add(received(testPeer, 'm$i'));
      }

      final page = await store.page(testPeer.aci, before: 4, limit: 2);
      expect(page.messages.map((m) => m.body), ['m2', 'm3']);
      expect(page.hasOlder, isTrue);

      final last = await store.page(testPeer.aci, before: 2, limit: 2);
      expect(last.messages.map((m) => m.body), ['m1']);
      expect(last.hasOlder, isFalse);

      expect(
        await store.page(testPeer.aci, before: 1, limit: 2),
        MessagePage.empty,
      );
    });

    test('só mensagens da conversa pedida', () async {
      await store.add(received(testPeer, 'a'));
      await store.add(received(other, 'b'));
      await store.add(outgoing(testPeer, 'c', 1));

      final page = await store.page(testPeer.aci, limit: 10);

      expect(page.messages.map((m) => m.body), ['a', 'c']);
    });
  });

  group('conversations', () {
    test(
      'da mais recente à mais antiga, com a última mensagem e as não lidas',
      () async {
        await store.add(received(testPeer, 'oi'));
        await store.add(received(testPeer, 'tudo bem?'));
        await store.add(received(other, 'olá'));
        await store.add(outgoing(other, 'olá!', 1));

        final conversations = await store.conversations();

        expect(conversations.map((c) => c.id), [other.aci, testPeer.aci]);
        expect(conversations[0].last.body, 'olá!');
        expect(conversations[0].unread, 1);
        expect(conversations[1].last.body, 'tudo bem?');
        expect(conversations[1].unread, 2);
      },
    );

    test('markRead zera as não lidas da conversa', () async {
      await store.add(received(testPeer, 'oi'));
      await store.add(received(other, 'olá'));

      await store.markRead(testPeer.aci);

      final unread = {
        for (final c in await store.conversations()) c.id: c.unread,
      };
      expect(unread, {testPeer.aci: 0, other.aci: 1});
    });
  });

  group('setStatus', () {
    test('troca a situação da enviada pelo clientMessageId', () async {
      await store.add(outgoing(testPeer, 'a', 1));
      final second = await store.add(outgoing(testPeer, 'b', 2));

      final updated = await store.setStatus(
        second.clientMessageId!,
        MessageStatus.failed,
        failure: CoreError.sessionNotFound,
      );

      expect(updated?.id, second.id);
      expect(updated?.status, MessageStatus.failed);
      expect(updated?.failure, CoreError.sessionNotFound);
      final page = await store.page(testPeer.aci, limit: 10);
      expect(page.messages.map((m) => m.status), [
        MessageStatus.pending,
        MessageStatus.failed,
      ]);
    });

    test('id desconhecido: null', () async {
      expect(await store.setStatus(Uint8List(16), MessageStatus.sent), isNull);
    });
  });
}
