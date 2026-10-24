import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:falaai_app/core/messenger.dart';
import 'package:falaai_app/core/sender_certificate.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const peer = DeviceAddress(
    aci: '00000000-0000-4000-8000-000000000001',
    deviceId: 1,
  );
  const server = ServerConfig(
    gatewayUrl: 'ws://127.0.0.1:8080',
    accountsUrl: 'http://127.0.0.1:8080',
    rootCertificates: [],
  );
  const token = 'token-do-dispositivo';
  const certificateName = SenderCertificates.storageName;
  final messageId = Uint8List.fromList(List.filled(16, 9));

  late MemorySecretStore store;
  late RecordingCore core;
  late Messenger messenger;

  setUp(() {
    store = MemorySecretStore();
    core = RecordingCore();
    messenger = Messenger(
      core,
      SenderCertificates(store),
      newMessageId: () => messageId,
    );
  });

  group('onRegistered', () {
    test('conecta antes de pedir o certificado ao accounts', () async {
      await messenger.onRegistered(server, token);

      expect(core.calls, [
        'connect',
        'fetchSenderCertificate',
        'setSenderCertificate',
      ]);
      expect(core.connections.single.token, token);
      expect(core.connections.single.server.gatewayUrl, server.gatewayUrl);
    });

    test('guarda o certificado que veio pelo core', () async {
      await messenger.onRegistered(server, token);

      expect(core.certificates, [
        [100],
      ]);
      expect(store.values[certificateName], base64Encode([100]));
    });

    test('falha do accounts sobe e nada é guardado', () async {
      core.fetchErrors.add(CoreError.network);

      await expectLater(
        messenger.onRegistered(server, token),
        throwsA(CoreError.network),
      );
      expect(store.values, isNot(contains(certificateName)));
    });
  });

  group('seal', () {
    test('cifra para o contato com um id novo', () async {
      final message = await messenger.seal(peer, utf8.encode('oi'));

      expect(message.peer, peer);
      expect(message.clientMessageId, messageId);
      expect(utf8.decode(message.envelope.body), 'oi');
      expect(core.calls, ['encrypt']);
    });

    test('sem certificado, busca outro pelo core e cifra de novo', () async {
      core.encryptErrors.add(CoreError.noSenderCertificate);

      await messenger.seal(peer, utf8.encode('oi'));

      expect(core.calls, [
        'encrypt',
        'fetchSenderCertificate',
        'setSenderCertificate',
        'encrypt',
      ]);
      expect(store.values[certificateName], base64Encode([100]));
    });

    test('não envia nada', () async {
      await messenger.seal(peer, utf8.encode('oi'));

      expect(core.sent, isEmpty);
    });
  });

  group('deliver', () {
    test('envia o envelope selado com o id da mensagem', () async {
      final message = await messenger.seal(peer, utf8.encode('oi'));

      await messenger.deliver(message);

      final sent = core.sent.single;
      expect(sent.peer, peer);
      expect(sent.id, messageId);
      expect(utf8.decode(sent.body), 'oi');
    });

    test(
      'reenviar depois de falha repete envelope e id sem cifrar de novo',
      () async {
        final message = await messenger.seal(peer, utf8.encode('oi'));
        core.sendErrors.add(CoreError.network);

        await expectLater(
          messenger.deliver(message),
          throwsA(CoreError.network),
        );
        await messenger.deliver(message);

        expect(core.encrypts, 1);
        expect(core.sent.single.id, messageId);
      },
    );
  });

  test('incoming entrega as mensagens que o core decifrou', () async {
    final received = ChatEvent.messageReceived(
      from: peer,
      body: Uint8List.fromList(utf8.encode('olá')),
    );

    final next = messenger.incoming().first;
    core.deliveries.add(received);

    expect(await next, received);
  });

  test('disconnect fecha a conexão do core', () async {
    await messenger.disconnect();

    expect(core.calls, ['disconnect']);
  });

  group('randomMessageId', () {
    test('é um UUID v4 de 16 bytes', () {
      final id = randomMessageId(Random(1));

      expect(id, hasLength(16));
      expect(id[6] >> 4, 4, reason: 'versão 4');
      expect(id[8] >> 6, 2, reason: 'variante RFC 4122');
    });

    test('cada chamada gera um id diferente', () {
      expect(randomMessageId(), isNot(randomMessageId()));
    });
  });

  test('CoreSenderCertificateSource busca pelo core', () async {
    final certificate = await CoreSenderCertificateSource(core).fetch();

    expect(certificate, [100]);
    expect(core.calls, ['fetchSenderCertificate']);
  });
}
