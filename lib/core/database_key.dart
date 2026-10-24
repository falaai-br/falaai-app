import 'dart:convert';
import 'dart:typed_data';

import 'package:falaai_core/falaai_core.dart';
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

/// Chave de 256 bits do SQLCipher do falaai-core. Gerada pelo core no primeiro uso e guardada
/// em [SecretStore]; o Dart só a guarda e repassa ao core ao abrir o banco.
class DatabaseKey {
  /// [generate] é o gerador do core ([generateDbKey]), que exige a ponte inicializada; os
  /// testes sem biblioteca nativa injetam outro.
  DatabaseKey(this._store, {Future<Uint8List> Function()? generate})
    : _generate = generate ?? generateDbKey;

  static const storageName = 'falaai.database_key';
  static const length = 32;

  final SecretStore _store;
  final Future<Uint8List> Function() _generate;

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
    final key = await _generate();
    if (key.length != length) {
      throw const FormatException('chave gerada com tamanho inválido');
    }
    await _store.write(storageName, base64Encode(key));
    return key;
  }
}
