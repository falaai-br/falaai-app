import 'dart:convert';
import 'dart:typed_data';

import 'package:falaai_app/core/database_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late MemorySecretStore secrets;
  late FakeKeyGenerator generator;

  setUp(() {
    secrets = MemorySecretStore();
    generator = FakeKeyGenerator();
  });

  DatabaseKey databaseKey(MemorySecretStore store) =>
      DatabaseKey(store, generate: generator.call);

  test(
    'pede a chave ao core no primeiro uso e guarda no SecretStore',
    () async {
      final key = await databaseKey(secrets).loadOrCreate();

      expect(generator.calls, 1);
      expect(key, hasLength(32));
      expect(base64Decode(secrets.values[DatabaseKey.storageName]!), key);
    },
  );

  test('reabre com a chave guardada, sem gerar outra', () async {
    final first = await databaseKey(secrets).loadOrCreate();
    final stored = secrets.values[DatabaseKey.storageName];

    final second = await databaseKey(secrets).loadOrCreate();

    expect(generator.calls, 1);
    expect(second, first);
    expect(secrets.values[DatabaseKey.storageName], stored);
  });

  test('chaves de aparelhos diferentes não coincidem', () async {
    final a = await databaseKey(MemorySecretStore()).loadOrCreate();
    final b = await databaseKey(MemorySecretStore()).loadOrCreate();

    expect(generator.calls, 2);
    expect(a, isNot(b));
  });

  test('chave gerada com tamanho errado é erro e não é guardada', () async {
    generator.next = Uint8List(16);

    await expectLater(
      databaseKey(secrets).loadOrCreate(),
      throwsFormatException,
    );
    expect(secrets.values, isEmpty);
  });

  for (final (name, stored) in [
    ('curta', base64Encode(List.filled(16, 1))),
    ('fora de base64', '%%%'),
  ]) {
    test('chave guardada $name é erro e não é substituída', () async {
      secrets.values[DatabaseKey.storageName] = stored;

      await expectLater(
        databaseKey(secrets).loadOrCreate(),
        throwsFormatException,
      );
      expect(generator.calls, 0);
      expect(secrets.values[DatabaseKey.storageName], stored);
    });
  }
}
