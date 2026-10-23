import 'dart:convert';
import 'dart:typed_data';

import 'package:falaai_app/core/sender_certificate.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Fonte que entrega certificados numerados e conta as buscas.
class CountingSource implements SenderCertificateSource {
  var fetches = 0;

  @override
  Future<Uint8List> fetch() async => Uint8List.fromList([++fetches]);
}

void main() {
  const peer = DeviceAddress(
    aci: '00000000-0000-4000-8000-000000000001',
    deviceId: 1,
  );
  const name = SenderCertificates.storageName;

  late MemorySecretStore store;
  late RecordingCore core;
  late CountingSource source;
  late SenderCertificates certificates;

  setUp(() {
    store = MemorySecretStore();
    core = RecordingCore();
    source = CountingSource();
    certificates = SenderCertificates(store);
  });

  group('restore', () {
    test('sem certificado guardado não entrega nada', () async {
      await certificates.restore(core);

      expect(core.certificates, isEmpty);
    });

    test('entrega ao core o certificado guardado', () async {
      store.values[name] = base64Encode([7, 8, 9]);

      await certificates.restore(core);

      expect(core.certificates, [
        [7, 8, 9],
      ]);
    });

    test('certificado vencido fica de fora sem erro', () async {
      store.values[name] = base64Encode([7]);
      core.certificateErrors.add(CoreError.invalidSenderCertificate);

      await certificates.restore(core);

      expect(core.certificates, isEmpty);
    });

    test('outro erro do core sobe', () async {
      store.values[name] = base64Encode([7]);
      core.certificateErrors.add(CoreError.storage);

      await expectLater(certificates.restore(core), throwsA(CoreError.storage));
    });
  });

  group('renew', () {
    test('busca, entrega ao core e guarda', () async {
      await certificates.renew(core, source);

      expect(core.certificates, [
        [1],
      ]);
      expect(store.values[name], base64Encode([1]));
    });

    test('certificado recusado pelo core não é guardado', () async {
      store.values[name] = base64Encode([7]);
      core.certificateErrors.add(CoreError.invalidSenderCertificate);

      await expectLater(
        certificates.renew(core, source),
        throwsA(CoreError.invalidSenderCertificate),
      );
      expect(store.values[name], base64Encode([7]));
    });
  });

  group('encrypt', () {
    Future<Envelope> encrypt() => certificates.encrypt(
      core,
      source,
      peer: peer,
      plaintext: utf8.encode('oi'),
    );

    test('com certificado válido cifra sem buscar outro', () async {
      final envelope = await encrypt();

      expect(utf8.decode(envelope.body), 'oi');
      expect(source.fetches, 0);
    });

    test('sem certificado renova uma vez e cifra de novo', () async {
      core.encryptErrors.add(CoreError.noSenderCertificate);

      await encrypt();

      expect(source.fetches, 1);
      expect(core.encrypts, 2);
      expect(store.values[name], base64Encode([1]));
    });

    test('se ainda falta certificado depois de renovar, o erro sobe', () async {
      core.encryptErrors.addAll([
        CoreError.noSenderCertificate,
        CoreError.noSenderCertificate,
      ]);

      await expectLater(encrypt(), throwsA(CoreError.noSenderCertificate));
      expect(source.fetches, 1);
    });

    test('outro erro do core sobe sem renovar', () async {
      core.encryptErrors.add(CoreError.sessionNotFound);

      await expectLater(encrypt(), throwsA(CoreError.sessionNotFound));
      expect(source.fetches, 0);
    });
  });
}
