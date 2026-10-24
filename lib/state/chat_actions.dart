import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:falaai_core/falaai_core.dart';

import '../chat/typing.dart';
import 'actions.dart';
import 'app_state.dart';

/// Mensagens por página na tela de chat.
const messagePageSize = 50;

/// Mensagens recebidas lidas do core por chamada, ao abrir o app.
const restoreBatchSize = 200;

/// Depois de [OpenCoreAction]: assina os eventos do core (antes de conectar, para ele
/// confirmar as entregas), traz para o [Dependencies.chat] as recebidas que o core gravou
/// enquanto o app estava fechado e carrega a lista de conversas. Sem core aberto, não faz nada.
class StartChatAction extends AppAction {
  @override
  Future<AppState?> reduce() async {
    final core = deps.core;
    if (core == null) return null;
    await deps.coreEvents?.cancel();
    deps.coreEvents = core.events().listen(
      (event) => dispatch(CoreEventAction(event)),
    );
    await deps.typingEvents?.cancel();
    deps.typingEvents = deps.typing.incoming().listen(
      (event) =>
          dispatch(PeerTypingAction(event.from.aci, typing: event.typing)),
    );
    await _restore(core);
    return state.copyWith(
      chat: state.chat.copyWith(conversations: await deps.chat.conversations()),
    );
  }

  /// Lê do core, em lotes a partir do último id gravado, o que ainda não está no store.
  Future<void> _restore(FalaaiCore core) async {
    var after = await deps.chat.lastCoreId();
    while (true) {
      final batch = await core.receivedMessages(
        after: after,
        limit: restoreBatchSize,
      );
      for (final received in batch) {
        await deps.chat.add(
          Message(
            id: 0,
            peer: received.from,
            body: _text(received.body),
            at: DateTime.fromMillisecondsSinceEpoch(
              received.serverTimestamp.toInt(),
            ),
            status: MessageStatus.received,
            coreId: received.id,
            identityChanged: received.identityChanged,
          ),
        );
        after = received.id;
      }
      if (batch.length < restoreBatchSize) return;
    }
  }
}

/// Um evento do core: mensagem recebida, enviada ou recusada.
class CoreEventAction extends _ChatAction {
  CoreEventAction(this.event);

  final ChatEvent event;

  @override
  Future<AppState?> reduce() async {
    final message = switch (event) {
      ChatEvent_MessageReceived(
        :final id,
        :final from,
        :final body,
        :final identityChanged,
      ) =>
        await deps.chat.add(
          Message(
            id: 0,
            peer: from,
            body: _text(body),
            at: deps.now(),
            status: MessageStatus.received,
            coreId: id,
            identityChanged: identityChanged,
          ),
        ),
      ChatEvent_MessageSent(:final clientMessageId) =>
        await deps.chat.setStatus(clientMessageId, MessageStatus.sent),
      ChatEvent_MessageFailed(:final clientMessageId, :final error) =>
        await deps.chat.setStatus(
          clientMessageId,
          MessageStatus.failed,
          failure: error,
        ),
    };
    if (message == null) return null;
    // Quem mandou mensagem parou de digitar.
    final typing = message.outgoing
        ? state.chat.typing
        : _withoutTyping(message.conversationId);
    return withMessage(message, typing: typing);
  }

  Set<String> _withoutTyping(String conversationId) {
    deps.typingTimers.remove(conversationId)?.cancel();
    return {...state.chat.typing}..remove(conversationId);
  }
}

/// Abre a tela de chat com a conta [conversationId]: carrega a primeira página e marca as
/// recebidas como lidas.
class OpenConversationAction extends AppAction {
  OpenConversationAction(this.conversationId);

  final String conversationId;

  @override
  Future<AppState?> reduce() async {
    final known = state.chat.conversations
        .where((conversation) => conversation.id == conversationId)
        .firstOrNull;
    // Conversa nova: o primeiro dispositivo da conta, até uma mensagem dele dizer outro.
    final peer = known?.peer ?? DeviceAddress(aci: conversationId, deviceId: 1);
    final page = await deps.chat.page(conversationId, limit: messagePageSize);
    await deps.chat.markRead(conversationId);
    return state.copyWith(
      chat: state.chat.copyWith(
        conversations: await deps.chat.conversations(),
        open: () => OpenConversation(
          peer: peer,
          messages: page.messages,
          hasOlder: page.hasOlder,
        ),
      ),
    );
  }
}

/// Saiu da tela de chat.
class CloseConversationAction extends AppAction {
  @override
  AppState reduce() {
    deps.typingSentAt = null;
    return state.copyWith(chat: state.chat.copyWith(open: () => null));
  }
}

/// Rolou até o início da janela: traz a página anterior. Uma chamada por vez.
class LoadOlderMessagesAction extends AppAction with NonReentrant {
  @override
  Future<AppState?> reduce() async {
    final open = state.chat.open;
    if (open == null || !open.hasOlder || open.messages.isEmpty) return null;
    final page = await deps.chat.page(
      open.id,
      before: open.messages.first.id,
      limit: messagePageSize,
    );
    final current = state.chat.open;
    if (current == null || current.id != open.id) return null;
    return state.copyWith(
      chat: state.chat.copyWith(
        open: () => current.copyWith(
          messages: [...page.messages, ...current.messages],
          hasOlder: page.hasOlder,
        ),
      ),
    );
  }
}

/// Envia [text] ao contato da conversa aberta pela outbox do core: a mensagem aparece como
/// pendente e muda com [ChatEvent.messageSent] ou [ChatEvent.messageFailed]. Se o core
/// recusar na hora (sem conta, banco), ela já aparece como falha.
class SendMessageAction extends _ChatAction {
  SendMessageAction(this.text);

  final String text;

  @override
  Future<AppState?> reduce() async {
    final open = state.chat.open;
    final core = deps.core;
    final body = text.trim();
    if (open == null || core == null || body.isEmpty) return null;
    deps.typingSentAt = null;
    await deps.typing.send(open.peer, typing: false);
    Message draft;
    try {
      final clientMessageId = await core.sendMessage(
        peer: open.peer,
        body: utf8.encode(body),
      );
      draft = Message(
        id: 0,
        peer: open.peer,
        body: body,
        at: deps.now(),
        status: MessageStatus.pending,
        clientMessageId: clientMessageId,
      );
    } on CoreError catch (error) {
      draft = Message(
        id: 0,
        peer: open.peer,
        body: body,
        at: deps.now(),
        status: MessageStatus.failed,
        failure: error,
      );
    }
    return withMessage(await deps.chat.add(draft));
  }
}

/// O contato da conversa [conversationId] começou ou parou de digitar. Sem aviso novo em
/// [typingTimeout], o indicador some sozinho.
class PeerTypingAction extends AppAction {
  PeerTypingAction(this.conversationId, {required this.typing});

  final String conversationId;
  final bool typing;

  @override
  AppState reduce() {
    deps.typingTimers.remove(conversationId)?.cancel();
    if (typing) {
      deps.typingTimers[conversationId] = Timer(
        typingTimeout,
        () => dispatch(PeerTypingAction(conversationId, typing: false)),
      );
    }
    final set = {...state.chat.typing};
    if (typing) {
      set.add(conversationId);
    } else {
      set.remove(conversationId);
    }
    return state.copyWith(chat: state.chat.copyWith(typing: set));
  }
}

/// Este usuário está ([typing]) ou parou de digitar na conversa aberta. "Digitando" sai no
/// máximo a cada [typingRefresh]; "parou" só se "digitando" saiu antes.
class ComposerTypingAction extends AppAction {
  ComposerTypingAction({required this.typing});

  final bool typing;

  @override
  Future<AppState?> reduce() async {
    final open = state.chat.open;
    if (open == null) return null;
    final now = deps.now();
    if (typing) {
      final last = deps.typingSentAt;
      if (last != null && now.difference(last) < typingRefresh) return null;
      deps.typingSentAt = now;
    } else {
      if (deps.typingSentAt == null) return null;
      deps.typingSentAt = null;
    }
    await deps.typing.send(open.peer, typing: typing);
    return null;
  }
}

/// Action que muda uma mensagem e precisa refletir isso na lista e na conversa aberta.
abstract class _ChatAction extends AppAction {
  /// O estado com [message] gravada: a lista recalculada e, se a conversa dela está aberta, a
  /// janela com a mensagem (nova no fim, ou trocada no lugar) e as recebidas marcadas lidas.
  Future<AppState> withMessage(Message message, {Set<String>? typing}) async {
    var open = state.chat.open;
    if (open != null && open.id == message.conversationId) {
      final index = open.messages.indexWhere((m) => m.id == message.id);
      open = open.copyWith(
        messages: index < 0
            ? [...open.messages, message]
            : [
                for (final (i, m) in open.messages.indexed)
                  i == index ? message : m,
              ],
      );
      if (!message.outgoing) await deps.chat.markRead(open.id);
    }
    return state.copyWith(
      chat: state.chat.copyWith(
        conversations: await deps.chat.conversations(),
        open: () => open,
        typing: typing,
      ),
    );
  }
}

/// Texto decifrado em UTF-8; bytes inválidos viram U+FFFD em vez de derrubar a conversa.
String _text(List<int> body) => utf8.decode(body, allowMalformed: true);
