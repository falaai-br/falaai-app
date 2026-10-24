import 'dart:math';
import 'dart:typed_data';

import 'package:falaai_core/falaai_core.dart';

import 'sender_certificate.dart';

/// Envelope selado pronto para o servidor, com o id que o identifica. Reenviar o mesmo
/// [OutgoingMessage] (mesmo envelope, mesmo id) deixa o destinatário deduplicar; cifrar de novo
/// geraria outra mensagem.
class OutgoingMessage {
  const OutgoingMessage({
    required this.peer,
    required this.clientMessageId,
    required this.envelope,
  });

  final DeviceAddress peer;

  /// UUID em 16 bytes.
  final Uint8List clientMessageId;

  final Envelope envelope;
}

/// Envio e recebimento de mensagens pelo transporte do falaai-core, com sealed sender. Os
/// sockets e o HTTPS do `accounts` são do core; aqui só se decide a ordem das chamadas e quando
/// renovar o certificado de remetente.
class Messenger {
  /// [newMessageId] gera o `client_message_id`; os testes injetam ids fixos.
  Messenger(
    this._core,
    this._certificates, {
    Uint8List Function()? newMessageId,
  }) : _source = CoreSenderCertificateSource(_core),
       _newMessageId = newMessageId ?? randomMessageId;

  final FalaaiCore _core;
  final SenderCertificates _certificates;
  final SenderCertificateSource _source;
  final Uint8List Function() _newMessageId;

  /// Mensagens que o core decifrou. Assinar antes de [connect]: sem assinante o core
  /// não confirma as entregas, que voltam só na próxima conexão. Assinar de novo substitui o
  /// assinante anterior.
  Stream<ChatEvent> incoming() => _core.events();

  /// Conecta ao servidor com o token que o `accounts` emitiu no registro. Exige o endereço local
  /// no core. Volta logo: o core conecta e reconecta em segundo plano.
  Future<void> connect(ServerConfig server, String token) =>
      _core.connect(server: server, token: token);

  /// Logo depois do registro e da publicação do bundle de chaves: conecta e pede o primeiro
  /// certificado de remetente, para a primeira mensagem já sair selada. O `accounts` só emite
  /// o certificado depois de conhecer a identity key do dispositivo.
  Future<void> onRegistered(ServerConfig server, String token) async {
    await connect(server, token);
    await _certificates.renew(_core, _source);
  }

  /// Cifra e sela [plaintext] para [peer], renovando o certificado de remetente se o core
  /// pedir. Não envia: o resultado vai para [deliver], e de novo em caso de falha.
  Future<OutgoingMessage> seal(DeviceAddress peer, List<int> plaintext) async {
    final envelope = await _certificates.encrypt(
      _core,
      _source,
      peer: peer,
      plaintext: plaintext,
    );
    return OutgoingMessage(
      peer: peer,
      clientMessageId: _newMessageId(),
      envelope: envelope,
    );
  }

  /// Entrega [message] ao servidor. Volta quando o servidor gravou na fila do destinatário.
  /// Com a profile key do contato o core usa o socket não autenticado; sem ela, o autenticado.
  Future<void> deliver(OutgoingMessage message) => _core.send(
    peer: message.peer,
    clientMessageId: message.clientMessageId,
    envelope: message.envelope,
  );

  /// Fecha a conexão com o servidor.
  Future<void> disconnect() => _core.disconnect();
}

/// UUID v4 aleatório em 16 bytes, para o `client_message_id`. Não é segredo: só identifica a
/// mensagem para o destinatário deduplicar.
Uint8List randomMessageId([Random? random]) {
  final source = random ?? Random.secure();
  final id = Uint8List.fromList(List.generate(16, (_) => source.nextInt(256)));
  id[6] = (id[6] & 0x0f) | 0x40;
  id[8] = (id[8] & 0x3f) | 0x80;
  return id;
}
