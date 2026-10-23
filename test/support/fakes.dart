import 'dart:typed_data';

import 'package:falaai_app/core/database_key.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Handle do core que não toca a biblioteca nativa.
class FakeCore extends Fake implements FalaaiCore {}

/// [FakeCore] que registra os certificados de remetente aceitos e as cifras. Os erros
/// programados saem, em ordem, nas próximas chamadas.
class RecordingCore extends FakeCore {
  final certificates = <List<int>>[];
  final certificateErrors = <CoreError>[];
  final encryptErrors = <CoreError>[];
  var encrypts = 0;

  @override
  Future<void> setSenderCertificate({required List<int> certificate}) async {
    if (certificateErrors.isNotEmpty) throw certificateErrors.removeAt(0);
    certificates.add(List.of(certificate));
  }

  @override
  Future<Envelope> encrypt({
    required DeviceAddress peer,
    required List<int> plaintext,
  }) async {
    encrypts++;
    if (encryptErrors.isNotEmpty) throw encryptErrors.removeAt(0);
    return Envelope(body: Uint8List.fromList(plaintext));
  }
}

/// [SecretStore] em memória.
class MemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async => values[name] = value;
}

/// Trust root de teste: chave pública Curve25519 da libsignal (tipo 0x05 e 32 bytes).
final testTrustRoot = Uint8List.fromList([0x05, ...List.filled(32, 0x42)]);
