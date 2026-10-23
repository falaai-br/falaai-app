// Abertura do core pela ponte gerada (frb_generated) com a biblioteca nativa mockada.
// ignore_for_file: implementation_imports
import 'dart:io';

import 'package:falaai_app/core/database_key.dart';
import 'package:falaai_app/core/open_core.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:falaai_core/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fakes.dart';

/// API da ponte que registra as aberturas em vez de chamar o Rust.
class RecordingApi extends Fake implements FalaaiCoreLibApi {
  final opened = <({String dbPath, List<int> dbKey})>[];

  @override
  Future<FalaaiCore> crateApiFalaaiCoreOpen({
    required String dbPath,
    required List<int> dbKey,
  }) async {
    opened.add((dbPath: dbPath, dbKey: List.of(dbKey)));
    return FakeCore();
  }
}

void main() {
  final api = RecordingApi();
  final dataDir = Directory('/dados/do/app');

  setUpAll(() => FalaaiCoreLib.initMock(api: api));
  setUp(api.opened.clear);

  test('abre o banco no diretório de dados com a chave guardada', () async {
    final secrets = MemorySecretStore();

    await openFalaaiCore(secrets: secrets, dataDir: () async => dataDir);
    await openFalaaiCore(secrets: secrets, dataDir: () async => dataDir);

    expect(api.opened, hasLength(2));
    final stored = await DatabaseKey(secrets).loadOrCreate();
    for (final open in api.opened) {
      expect(open.dbPath, '/dados/do/app/falaai.db');
      expect(open.dbKey, stored);
    }
  });

  test('chave guardada inválida não chega ao core', () async {
    final secrets = MemorySecretStore()
      ..values[DatabaseKey.storageName] = 'AAAA';

    await expectLater(
      openFalaaiCore(secrets: secrets, dataDir: () async => dataDir),
      throwsFormatException,
    );
    expect(api.opened, isEmpty);
  });
}
