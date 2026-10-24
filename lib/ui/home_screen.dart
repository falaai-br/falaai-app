import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../router.dart';
import '../state/actions.dart';
import '../state/app_state.dart';
import '../state/onboarding_actions.dart';
import 'chat/contact.dart';
import 'chat/message_time.dart';
import 'chat/new_conversation_dialog.dart';

/// Tela inicial: a lista de conversas, depois que o core abre.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = context.select((state) => state.core);
    final loading =
        context.select((state) => state.account.status) ==
        AccountStatus.loading;
    final pinReminder = context.select((state) => state.account.pinReminderDue);
    final ready = core == CoreStatus.ready && !loading;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      floatingActionButton: ready
          ? FloatingActionButton.extended(
              onPressed: () => _newConversation(context),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.chatNew),
            )
          : null,
      body: Column(
        children: [
          if (pinReminder && core == CoreStatus.ready) const _PinReminder(),
          Expanded(
            child: switch (core) {
              CoreStatus.failed => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.coreFailed, textAlign: TextAlign.center),
                ),
              ),
              CoreStatus.starting => Center(
                child: Semantics(
                  label: l10n.coreStarting,
                  child: const CircularProgressIndicator(),
                ),
              ),
              CoreStatus.ready when loading => Center(
                child: Semantics(
                  label: l10n.coreStarting,
                  child: const CircularProgressIndicator(),
                ),
              ),
              CoreStatus.ready => const _ConversationList(),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _newConversation(BuildContext context) async {
    final aci = await showNewConversationDialog(context);
    if (aci != null && context.mounted) {
      unawaited(context.push(Routes.chatWith(aci)));
    }
  }
}

/// As conversas, da mais recente à mais antiga; vazia, o convite a começar.
class _ConversationList extends StatelessWidget {
  const _ConversationList();

  @override
  Widget build(BuildContext context) {
    final conversations = context.select((state) => state.chat.conversations);
    if (conversations.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).homeEmpty));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: conversations.length,
      itemBuilder: (context, index) =>
          _ConversationTile(conversation: conversations[index]),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final typing = context.select(
      (state) => state.chat.typing.contains(conversation.id),
    );
    final last = conversation.last;
    final preview = last.outgoing
        ? l10n.chatPreviewOutgoing(last.body)
        : last.body;
    final unread = conversation.unread;
    return ListTile(
      key: ValueKey(conversation.id),
      leading: CircleAvatar(
        child: ExcludeSemantics(child: Text(contactInitial(conversation.peer))),
      ),
      title: Text(contactName(l10n, conversation.id)),
      subtitle: typing
          ? Text(
              l10n.chatTyping,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            )
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMessageTime(context, last.at),
            style: theme.textTheme.labelSmall,
          ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Semantics(
              label: l10n.chatUnread(unread),
              child: Badge(
                label: ExcludeSemantics(child: Text('$unread')),
                largeSize: 20,
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push(Routes.chatWith(conversation.id)),
    );
  }
}

/// Lembrete do PIN adiado: leva à tela do PIN ou adia de novo. Sem tom de alarme.
class _PinReminder extends StatelessWidget {
  const _PinReminder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pinReminder),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.dispatch(DeferPinAction()),
                  child: Text(l10n.pinLater),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.pin),
                  child: Text(l10n.pinCreate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
