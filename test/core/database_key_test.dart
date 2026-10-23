import 'dart:convert';

import 'package:falaai_app/core/database_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late MemorySecretStore secrets;

  setUp(() => secrets = MemorySecretStore());

  test('gera 32 bytes no primeiro uso e guarda no SecretStore', () async {
    final key = await DatabaseKey(secrets).loadOrCreate();

    expect(key, hasLength(32));
    expect(base64Decode(secrets.values[DatabaseKey.storageName]!), key);
  });

  test('reabre com a chave guardada, sem gerar outra', () async {
    final first = await DatabaseKey(secrets).loadOrCreate();
    final stored = secrets.values[DatabaseKey.storageName];

    final second = await DatabaseKey(secrets).loadOrCreate();

    expect(second, first);
    expect(secrets.values[DatabaseKey.storageName], stored);
  });

  test('chaves de aparelhos diferentes não coincidem', () async {
    final a = await DatabaseKey(MemorySecretStore()).loadOrCreate();
    final b = await DatabaseKey(MemorySecretStore()).loadOrCreate();

    expect(a, isNot(b));
  });

  for (final (name, stored) in [
    ('curta', base64Encode(List.filled(16, 1))),
    ('fora de base64', '%%%'),
  ]) {
    test('chave guardada $name é erro e não é substituída', () async {
      secrets.values[DatabaseKey.storageName] = stored;

      await expectLater(
        DatabaseKey(secrets).loadOrCreate(),
        throwsFormatException,
      );
      expect(secrets.values[DatabaseKey.storageName], stored);
    });
  }
}
