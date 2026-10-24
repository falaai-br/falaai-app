import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/foundation.dart';

import 'message.dart';

/// Mensagens e conversas como a UI as lê: por página, com cursor, nunca a conversa inteira.
///
/// O banco das mensagens é o SQLCipher do core: as recebidas já ficam lá e voltam por
/// `receivedMessages`. Enquanto o core não expõe conversas e mensagens por conversa, a
/// implementação é a [MemoryChatStore], reconstruída a cada abertura a partir do core; as
/// enviadas ainda não sobrevivem ao reinício. Trocar a implementação não muda as actions nem a
/// UI.
abstract interface class ChatStore {
  /// Conversas da mais recente à mais antiga, pela última mensagem.
  Future<List<ConversationSummary>> conversations();

  /// Até [limit] mensagens de [conversationId] com id menor que [before], ou as mais novas sem
  /// [before], da mais antiga à mais nova.
  Future<MessagePage> page(
    String conversationId, {
    int? before,
    required int limit,
  });

  /// Grava [message] e devolve a cópia com o id atribuído. Uma recebida com `coreId` já
  /// gravado volta como está, sem gravar de novo.
  Future<Message> add(Message message);

  /// Troca a situação da enviada com [clientMessageId] e devolve a mensagem atualizada, ou
  /// `null` se ela não está gravada.
  Future<Message?> setStatus(
    Uint8List clientMessageId,
    MessageStatus status, {
    CoreError? failure,
  });

  /// Zera as não lidas de [conversationId].
  Future<void> markRead(String conversationId);

  /// Maior `coreId` gravado, o cursor para `receivedMessages`; zero se nenhum.
  Future<int> lastCoreId();
}

/// [ChatStore] em memória.
class MemoryChatStore implements ChatStore {
  /// Mensagens por conversa, em ordem de id.
  final _conversations = <String, List<Message>>{};
  final _unread = <String, int>{};
  final _coreIds = <int, Message>{};
  var _nextId = 1;
  var _lastCoreId = 0;

  @override
  Future<List<ConversationSummary>> conversations() async {
    final summaries = [
      for (final MapEntry(key: id, value: messages) in _conversations.entries)
        if (messages.isNotEmpty)
          ConversationSummary(
            peer: messages.last.peer,
            last: messages.last,
            unread: _unread[id] ?? 0,
          ),
    ];
    summaries.sort((a, b) => b.last.id.compareTo(a.last.id));
    return summaries;
  }

  @override
  Future<MessagePage> page(
    String conversationId, {
    int? before,
    required int limit,
  }) async {
    final messages = _conversations[conversationId] ?? const <Message>[];
    var end = messages.length;
    if (before != null) {
      final first = messages.indexWhere((message) => message.id >= before);
      if (first >= 0) end = first;
    }
    final start = end - limit < 0 ? 0 : end - limit;
    return MessagePage(
      messages: List.unmodifiable(messages.sublist(start, end)),
      hasOlder: start > 0,
    );
  }

  @override
  Future<Message> add(Message message) async {
    final coreId = message.coreId;
    final existing = coreId == null ? null : _coreIds[coreId];
    if (existing != null) return existing;
    final stored = message.copyWith(id: _nextId++);
    _conversations.putIfAbsent(stored.conversationId, () => []).add(stored);
    if (coreId != null) {
      _coreIds[coreId] = stored;
      if (coreId > _lastCoreId) _lastCoreId = coreId;
    }
    if (stored.status == MessageStatus.received) {
      _unread.update(
        stored.conversationId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return stored;
  }

  @override
  Future<Message?> setStatus(
    Uint8List clientMessageId,
    MessageStatus status, {
    CoreError? failure,
  }) async {
    for (final messages in _conversations.values) {
      final index = messages.indexWhere(
        (message) => listEquals(message.clientMessageId, clientMessageId),
      );
      if (index < 0) continue;
      return messages[index] = messages[index].copyWith(
        status: status,
        failure: failure,
      );
    }
    return null;
  }

  @override
  Future<void> markRead(String conversationId) async =>
      _unread.remove(conversationId);

  @override
  Future<int> lastCoreId() async => _lastCoreId;
}
