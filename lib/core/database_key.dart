import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Onde a chave do banco fica guardada: Keychain no iOS, Keystore no Android.
abstract interface class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

/// [SecretStore] do aparelho, sobre o flutter_secure_storage.
class DeviceSecretStore implements SecretStore {
  DeviceSecretStore()
    : _storage = const FlutterSecureStorage(
        // Disponível depois do primeiro desbloqueio (push com o app fechado) e nunca
        // migrada para outro aparelho.
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        // Sem reset em erro do Keystore: uma chave nova trancaria o banco existente.
        aOptions: AndroidOptions(resetOnError: false),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}

/// Chave de 256 bits do SQLCipher do falaai-core. Gerada no primeiro uso e guardada em
/// [SecretStore]; o Dart só a repassa ao core ao abrir o banco.
class DatabaseKey {
  DatabaseKey(this._store, {Random? random})
    : _random = random ?? Random.secure();

  static const storageName = 'falaai.database_key';
  static const length = 32;

  final SecretStore _store;
  final Random _random;

  /// A chave guardada ou, no primeiro uso, uma nova. Uma chave guardada inválida é erro, não
  /// motivo para gerar outra: o banco cifrado com ela ficaria inacessível.
  Future<Uint8List> loadOrCreate() async {
    final stored = await _store.read(storageName);
    if (stored != null) {
      final key = base64Decode(stored);
      if (key.length != length) {
        throw const FormatException('chave do banco com tamanho inválido');
      }
      return key;
    }
    final key = Uint8List(length);
    for (var i = 0; i < length; i++) {
      key[i] = _random.nextInt(256);
    }
    await _store.write(storageName, base64Encode(key));
    return key;
  }
}
