import 'dart:async';
import 'dart:typed_data';

import 'package:falaai_app/core/database_key.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Handle do core que não toca a biblioteca nativa.
class FakeCore extends Fake implements FalaaiCore {}

/// [FakeCore] que registra os certificados de remetente aceitos, as cifras e o que passa pelo
/// transporte. Os erros programados saem, em ordem, nas próximas chamadas.
class RecordingCore extends FakeCore {
  final certificates = <List<int>>[];
  final certificateErrors = <CoreError>[];
  final encryptErrors = <CoreError>[];
  var encrypts = 0;

  /// Chamadas ao core na ordem em que chegaram, pelo nome do método.
  final calls = <String>[];
  final connections = <({ServerConfig server, String token})>[];
  final sent = <({DeviceAddress peer, List<int> id, List<int> body})>[];
  final sendErrors = <CoreError>[];
  final fetchErrors = <CoreError>[];
  var fetches = 0;

  /// O que entra aqui sai no stream de [events]. Vive o tanto do fake, sem nada a liberar.
  // ignore: close_sinks
  final deliveries = StreamController<ChatEvent>.broadcast();

  @override
  Future<void> connect({
    required ServerConfig server,
    required String token,
  }) async {
    calls.add('connect');
    connections.add((server: server, token: token));
  }

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  /// Certificados numerados a partir de 100, para não confundir com os de outras fontes.
  @override
  Future<Uint8List> fetchSenderCertificate() async {
    calls.add('fetchSenderCertificate');
    if (fetchErrors.isNotEmpty) throw fetchErrors.removeAt(0);
    return Uint8List.fromList([100 + fetches++]);
  }

  @override
  Future<void> send({
    required DeviceAddress peer,
    required List<int> clientMessageId,
    required Envelope envelope,
  }) async {
    calls.add('send');
    if (sendErrors.isNotEmpty) throw sendErrors.removeAt(0);
    sent.add((
      peer: peer,
      id: List.of(clientMessageId),
      body: List.of(envelope.body),
    ));
  }

  @override
  Stream<ChatEvent> events() {
    calls.add('events');
    return deliveries.stream;
  }

  @override
  Future<void> setSenderCertificate({required List<int> certificate}) async {
    calls.add('setSenderCertificate');
    if (certificateErrors.isNotEmpty) throw certificateErrors.removeAt(0);
    certificates.add(List.of(certificate));
  }

  @override
  Future<Envelope> encrypt({
    required DeviceAddress peer,
    required List<int> plaintext,
  }) async {
    calls.add('encrypt');
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

/// Gerador de chave do banco no lugar do `generateDbKey` do core: cada chamada devolve uma
/// chave diferente da anterior, ou a de [next] se programada.
class FakeKeyGenerator {
  var calls = 0;
  Uint8List? next;

  Future<Uint8List> call() async {
    calls++;
    final programmed = next;
    if (programmed != null) return programmed;
    return Uint8List(DatabaseKey.length)
      ..fillRange(0, DatabaseKey.length, calls);
  }
}

/// Trust root de teste: chave pública Curve25519 da libsignal (tipo 0x05 e 32 bytes).
final testTrustRoot = Uint8List.fromList([0x05, ...List.filled(32, 0x42)]);
