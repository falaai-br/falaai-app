import 'dart:async';
import 'dart:typed_data';

import 'package:falaai_app/account/accounts_api.dart';
import 'package:falaai_app/core/database_key.dart';
import 'package:falaai_app/state/actions.dart';
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

  /// Chaves geradas e endereço gravado no registro.
  var generatedKeys = 0;
  final keyErrors = <CoreError>[];
  DeviceAddress? localAddress;

  @override
  Future<AccountKeys> generateAccountKeys() async {
    calls.add('generateAccountKeys');
    if (keyErrors.isNotEmpty) throw keyErrors.removeAt(0);
    generatedKeys++;
    return testAccountKeys;
  }

  @override
  Future<void> setLocalAddress({required DeviceAddress address}) async {
    calls.add('setLocalAddress');
    localAddress = address;
  }

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

/// Parte pública de chaves de conta, com bytes distintos em cada campo.
final testAccountKeys = AccountKeys(
  registrationId: 4242,
  identityKey: Uint8List.fromList([5, 1, 1]),
  signedPreKey: SignedPreKey(
    id: 1,
    publicKey: Uint8List.fromList([5, 2]),
    signature: Uint8List.fromList([9, 2]),
  ),
  kyberLastResortPreKey: SignedPreKey(
    id: 2,
    publicKey: Uint8List.fromList([8, 3]),
    signature: Uint8List.fromList([9, 3]),
  ),
  preKeys: [
    PreKey(id: 10, publicKey: Uint8List.fromList([5, 10])),
    PreKey(id: 11, publicKey: Uint8List.fromList([5, 11])),
  ],
  kyberPreKeys: [
    SignedPreKey(
      id: 20,
      publicKey: Uint8List.fromList([8, 20]),
      signature: Uint8List.fromList([9, 20]),
    ),
  ],
);

/// Credenciais que o [FakeAccountsApi] devolve no registro.
const testDevice = DeviceCredentials(
  aci: '9d0652a3-dcc3-4d11-975f-74d61598733f',
  deviceId: 1,
  token: 'token-de-teste',
);

/// [AccountsApi] em memória. Os erros programados saem, em ordem, nas próximas chamadas de cada
/// rota.
class FakeAccountsApi implements AccountsApi {
  final calls = <String>[];
  final registrations = <({String phone, String code})>[];
  final uploads = <({DeviceCredentials device, AccountKeys keys})>[];
  final pins = <({DeviceCredentials device, String pin})>[];
  final registerErrors = <AccountsError>[];
  final uploadErrors = <AccountsError>[];
  final pinErrors = <AccountsError>[];

  /// Segura o registro até completar, para ver o estado de espera.
  Completer<void>? registerGate;

  @override
  Future<DeviceCredentials> register({
    required String phone,
    required String code,
  }) async {
    calls.add('register');
    registrations.add((phone: phone, code: code));
    await registerGate?.future;
    if (registerErrors.isNotEmpty) throw registerErrors.removeAt(0);
    return testDevice;
  }

  @override
  Future<void> uploadKeys(DeviceCredentials device, AccountKeys keys) async {
    calls.add('uploadKeys');
    if (uploadErrors.isNotEmpty) throw uploadErrors.removeAt(0);
    uploads.add((device: device, keys: keys));
  }

  @override
  Future<void> setRegistrationPin(DeviceCredentials device, String pin) async {
    calls.add('setRegistrationPin');
    if (pinErrors.isNotEmpty) throw pinErrors.removeAt(0);
    pins.add((device: device, pin: pin));
  }
}

/// Dependências da store para testes, com tudo em memória. [openCore] padrão abre um
/// [RecordingCore] novo.
Dependencies testDependencies({
  Future<FalaaiCore> Function()? openCore,
  MemorySecretStore? secrets,
  AccountsApi? accounts,
  DateTime Function()? now,
}) => Dependencies(
  openCore: openCore ?? () async => RecordingCore(),
  secrets: secrets ?? MemorySecretStore(),
  accounts: () => accounts ?? FakeAccountsApi(),
  now: now,
);
