import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

import '../../chat/typing.dart';
import '../../l10n/app_localizations.dart';
import '../../state/actions.dart';
import '../../state/app_state.dart';
import '../../state/chat_actions.dart';
import 'contact.dart';
import 'message_bubble.dart';

/// Conversa 1:1 com a conta [conversationId]: a janela de mensagens (rolar para cima traz a
/// página anterior), o indicador de digitação do contato e o compositor.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    context.dispatch(OpenConversationAction(widget.conversationId));
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      context.dispatch(OpenConversationAction(widget.conversationId));
    }
  }

  // Em deactivate a store ainda está ao alcance do contexto; em dispose, não.
  @override
  void deactivate() {
    context.dispatch(CloseConversationAction());
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final open = context.select((state) => state.chat.open);
    final conversation = open?.id == widget.conversationId ? open : null;
    final typing = context.select(
      (state) => state.chat.typing.contains(widget.conversationId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(contactName(l10n, widget.conversationId)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: conversation == null
                  ? Center(
                      child: Semantics(
                        label: l10n.waiting,
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  : _MessageList(conversation: conversation),
            ),
            if (typing)
              _TypingIndicator(name: contactName(l10n, widget.conversationId)),
            const _Composer(),
          ],
        ),
      ),
    );
  }
}

/// A janela de mensagens, da mais nova (embaixo) à mais antiga. No topo, enquanto houver
/// anteriores, o carregador pede a próxima página ao aparecer.
class _MessageList extends StatelessWidget {
  const _MessageList({required this.conversation});

  final OpenConversation conversation;

  @override
  Widget build(BuildContext context) {
    final messages = conversation.messages;
    if (messages.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.chatEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (conversation.hasOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          // A chave muda a cada página: o carregador nasce de novo e pede a seguinte.
          return _OlderMessagesLoader(
            key: ValueKey('older-${messages.first.id}'),
          );
        }
        final message = messages[messages.length - 1 - index];
        return MessageBubble(key: ValueKey(message.id), message: message);
      },
    );
  }
}

class _OlderMessagesLoader extends StatefulWidget {
  const _OlderMessagesLoader({super.key});

  @override
  State<_OlderMessagesLoader> createState() => _OlderMessagesLoaderState();
}

class _OlderMessagesLoaderState extends State<_OlderMessagesLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.dispatch(LoadOlderMessagesAction());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Semantics(
          label: AppLocalizations.of(context).chatLoadingOlder,
          child: const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          child: Text(
            l10n.chatTypingName(name),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto e botão de enviar. Avisa "digitando" enquanto o usuário escreve e "parou"
/// depois de [typingTimeout] parado, ao apagar tudo ou ao enviar.
class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    _text.dispose();
    super.dispose();
  }

  bool get _hasText => _text.text.trim().isNotEmpty;

  void _changed(String _) {
    setState(() {});
    _idle?.cancel();
    if (_hasText) {
      context.dispatch(ComposerTypingAction(typing: true));
      _idle = Timer(typingTimeout, () {
        if (mounted) context.dispatch(ComposerTypingAction(typing: false));
      });
    } else {
      context.dispatch(ComposerTypingAction(typing: false));
    }
  }

  void _send() {
    if (!_hasText) return;
    _idle?.cancel();
    context.dispatch(SendMessageAction(_text.text));
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l10n.chatComposerHint,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                isDense: true,
              ),
              onChanged: _changed,
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: l10n.chatSend,
            onPressed: _hasText ? _send : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
