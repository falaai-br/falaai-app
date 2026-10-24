import 'dart:convert';
import 'dart:typed_data';

import 'package:falaai_core/falaai_core.dart';

import 'database_key.dart';

/// Pede ao `accounts` um certificado de remetente novo para este dispositivo (vale 24h).
abstract interface class SenderCertificateSource {
  Future<Uint8List> fetch();
}

/// [SenderCertificateSource] pelo HTTPS do core (`GET /v1/certificate/sender` do `accounts`),
/// com o token do dispositivo. Exige o core conectado ([FalaaiCore.connect]); o Dart não abre
/// conexão com o servidor.
class CoreSenderCertificateSource implements SenderCertificateSource {
  const CoreSenderCertificateSource(this._core);

  final FalaaiCore _core;

  @override
  Future<Uint8List> fetch() => _core.fetchSenderCertificate();
}

/// Certificado de remetente do sealed sender. O core só o guarda em memória; aqui ele fica em
/// [SecretStore] (leva o ACI e a identidade do dispositivo), volta ao core a cada abertura e é
/// trocado quando o core o recusa.
class SenderCertificates {
  SenderCertificates(this._store);

  static const storageName = 'falaai.sender_certificate';

  final SecretStore _store;

  /// Reentrega ao core recém-aberto o certificado guardado. Um certificado vencido fica de fora:
  /// o próximo [encrypt] pede outro.
  Future<void> restore(FalaaiCore core) async {
    final stored = await _store.read(storageName);
    if (stored == null) return;
    try {
      await core.setSenderCertificate(certificate: base64Decode(stored));
    } on CoreError catch (e) {
      if (e != CoreError.invalidSenderCertificate) rethrow;
    }
  }

  /// Busca um certificado novo em [source], entrega ao core e guarda. Só guarda o que o core
  /// aceitou.
  Future<void> renew(FalaaiCore core, SenderCertificateSource source) async {
    final certificate = await source.fetch();
    await core.setSenderCertificate(certificate: certificate);
    await _store.write(storageName, base64Encode(certificate));
  }

  /// Cifra [plaintext] para [peer] com sealed sender. Se o core não tem certificado ou o dele
  /// venceu, renova uma vez por [source] e tenta de novo.
  Future<Envelope> encrypt(
    FalaaiCore core,
    SenderCertificateSource source, {
    required DeviceAddress peer,
    required List<int> plaintext,
  }) async {
    try {
      return await core.encrypt(peer: peer, plaintext: plaintext);
    } on CoreError catch (e) {
      if (e != CoreError.noSenderCertificate) rethrow;
    }
    await renew(core, source);
    return core.encrypt(peer: peer, plaintext: plaintext);
  }
}
