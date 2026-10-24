import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/foundation.dart';

/// Situação de uma mensagem na conversa. As recebidas são sempre [received]; as outras são o
/// caminho de uma enviada: outbox, servidor, aparelho do contato, lida.
enum MessageStatus {
  /// Na outbox do core, à espera de conexão ou de nova tentativa.
  pending,

  /// O servidor gravou na fila do destinatário.
  sent,

  /// O aparelho do contato recebeu (recibo de entrega).
  delivered,

  /// O contato leu (recibo de leitura).
  read,

  /// O core desistiu: reenviar igual não adianta.
  failed,

  /// Mensagem do contato.
  received,
}

/// Uma mensagem de texto 1:1, como a UI mostra. A conversa é a conta do contato
/// ([conversationId]); [peer] é o dispositivo dele, para onde as respostas vão.
@immutable
class Message {
  const Message({
    required this.id,
    required this.peer,
    required this.body,
    required this.at,
    required this.status,
    this.clientMessageId,
    this.coreId,
    this.failure,
    this.identityChanged = false,
  });

  /// Id local, crescente na ordem em que as mensagens foram gravadas: é o cursor da paginação.
  /// Zero numa mensagem ainda não gravada ([ChatStore.add] atribui o id).
  final int id;

  /// Dispositivo do contato.
  final DeviceAddress peer;

  /// Texto da mensagem.
  final String body;

  /// Quando foi recebida pelo servidor (recebidas) ou escrita (enviadas), no relógio local.
  final DateTime at;

  final MessageStatus status;

  /// Enviadas: o id que o core devolveu em `sendMessage`, para casar com os eventos
  /// `MessageSent` e `MessageFailed`.
  final Uint8List? clientMessageId;

  /// Recebidas: o id da mensagem no banco do core, para deduplicar com `receivedMessages`.
  final int? coreId;

  /// Por que uma enviada ficou [MessageStatus.failed].
  final CoreError? failure;

  /// Recebidas: a chave de identidade do contato mudou nesta mensagem; o código de segurança
  /// é outro.
  final bool identityChanged;

  /// ACI do contato: identifica a conversa.
  String get conversationId => peer.aci;

  bool get outgoing => status != MessageStatus.received;

  Message copyWith({int? id, MessageStatus? status, CoreError? failure}) =>
      Message(
        id: id ?? this.id,
        peer: peer,
        body: body,
        at: at,
        status: status ?? this.status,
        clientMessageId: clientMessageId,
        coreId: coreId,
        failure: failure ?? this.failure,
        identityChanged: identityChanged,
      );

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.peer == peer &&
      other.body == body &&
      other.at == at &&
      other.status == status &&
      listEquals(other.clientMessageId, clientMessageId) &&
      other.coreId == coreId &&
      other.failure == failure &&
      other.identityChanged == identityChanged;

  @override
  int get hashCode => Object.hash(
    id,
    peer,
    body,
    at,
    status,
    clientMessageId == null ? null : Object.hashAll(clientMessageId!),
    coreId,
    failure,
    identityChanged,
  );
}

/// Uma conversa na lista: o contato, a última mensagem e quantas recebidas ainda não lidas.
@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.peer,
    required this.last,
    required this.unread,
  });

  final DeviceAddress peer;
  final Message last;
  final int unread;

  String get id => peer.aci;

  @override
  bool operator ==(Object other) =>
      other is ConversationSummary &&
      other.peer == peer &&
      other.last == last &&
      other.unread == unread;

  @override
  int get hashCode => Object.hash(peer, last, unread);
}

/// Página de mensagens de uma conversa, da mais antiga à mais nova. [hasOlder] diz se há
/// mensagens antes da primeira.
@immutable
class MessagePage {
  const MessagePage({required this.messages, required this.hasOlder});

  static const empty = MessagePage(messages: [], hasOlder: false);

  final List<Message> messages;
  final bool hasOlder;

  @override
  bool operator ==(Object other) =>
      other is MessagePage &&
      listEquals(other.messages, messages) &&
      other.hasOlder == hasOlder;

  @override
  int get hashCode => Object.hash(Object.hashAll(messages), hasOlder);
}
