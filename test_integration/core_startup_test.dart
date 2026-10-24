// Abertura do core pela ponte gerada (frb_generated) com a biblioteca nativa mockada.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:falaai_app/core/database_key.dart';
import 'package:falaai_app/core/open_core.dart';
import 'package:falaai_app/core/sender_certificate.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:falaai_core/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fakes.dart';

/// API da ponte que registra as aberturas e as chaves geradas em vez de chamar o Rust.
class RecordingApi extends Fake implements FalaaiCoreLibApi {
  final opened = <({String dbPath, List<int> dbKey, List<int> trustRoot})>[];
  var core = RecordingCore();
  var keys = FakeKeyGenerator();

  @override
  Future<Uint8List> crateApiGenerateDbKey() => keys();

  @override
  Future<FalaaiCore> crateApiFalaaiCoreOpen({
    required String dbPath,
    required List<int> dbKey,
    required List<int> trustRoot,
  }) async {
    opened.add((
      dbPath: dbPath,
      dbKey: List.of(dbKey),
      trustRoot: List.of(trustRoot),
    ));
    return core;
  }
}

void main() {
  final api = RecordingApi();
  final dataDir = Directory('/dados/do/app');

  setUpAll(() => FalaaiCoreLib.initMock(api: api));
  setUp(() {
    api.opened.clear();
    api.core = RecordingCore();
    api.keys = FakeKeyGenerator();
  });

  Future<FalaaiCore> open(MemorySecretStore secrets) => openFalaaiCore(
    secrets: secrets,
    dataDir: () async => dataDir,
    trustRoot: testTrustRoot,
  );

  test('abre o banco no diretório de dados com a chave guardada', () async {
    final secrets = MemorySecretStore();

    await open(secrets);
    await open(secrets);

    expect(api.keys.calls, 1, reason: 'a chave nasce no core, uma vez');
    expect(api.opened, hasLength(2));
    final stored = await DatabaseKey(secrets).loadOrCreate();
    for (final open in api.opened) {
      expect(open.dbPath, '/dados/do/app/falaai.db');
      expect(open.dbKey, stored);
      expect(open.trustRoot, testTrustRoot);
    }
  });

  test('reentrega ao core o certificado de remetente guardado', () async {
    final secrets = MemorySecretStore()
      ..values[SenderCertificates.storageName] = base64Encode([1, 2, 3]);

    await open(secrets);

    expect(api.core.certificates, [
      [1, 2, 3],
    ]);
  });

  test('certificado guardado vencido não impede a abertura', () async {
    final secrets = MemorySecretStore()
      ..values[SenderCertificates.storageName] = base64Encode([1]);
    api.core.certificateErrors.add(CoreError.invalidSenderCertificate);

    await open(secrets);

    expect(api.opened, hasLength(1));
    expect(api.core.certificates, isEmpty);
  });

  test('chave guardada inválida não chega ao core', () async {
    final secrets = MemorySecretStore()
      ..values[DatabaseKey.storageName] = 'AAAA';

    await expectLater(open(secrets), throwsFormatException);
    expect(api.keys.calls, 0);
    expect(api.opened, isEmpty);
  });
}
