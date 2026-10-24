import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'message_time.dart';

/// Uma mensagem na conversa: as enviadas à direita, com a situação (recibo); as recebidas à
/// esquerda. Cores dos pares do Material 3, que garantem contraste AA; o leitor de tela ouve
/// quem mandou, a hora, a situação e o texto.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.now});

  final Message message;

  /// Relógio para a hora relativa; os testes injetam.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final outgoing = message.outgoing;
    final background = outgoing
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = outgoing ? colors.onPrimaryContainer : colors.onSurface;
    final time = formatMessageTime(context, message.at, now: now);
    final status = outgoing ? messageStatusText(l10n, message.status) : null;
    final failure = message.failure;
    final who = outgoing ? l10n.chatYou : null;
    return Padding(
      padding: EdgeInsets.only(
        left: outgoing ? 48 : 8,
        right: outgoing ? 8 : 48,
        top: 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: outgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.identityChanged)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.chatIdentityChanged,
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          MergeSemantics(
            child: Semantics(
              label: [?who, time, ?status].join(', '),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.body,
                        style: text.bodyLarge?.copyWith(color: foreground),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              time,
                              style: text.labelSmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                          if (outgoing) ...[
                            const SizedBox(width: 4),
                            ExcludeSemantics(
                              child: _StatusIcon(
                                status: message.status,
                                color: foreground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (message.status == MessageStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(
                failureText(l10n, failure),
                style: text.bodySmall?.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ícone do recibo de uma enviada.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, tint) = switch (status) {
      MessageStatus.pending => (Icons.schedule, color),
      MessageStatus.sent => (Icons.check, color),
      MessageStatus.delivered => (Icons.done_all, color),
      MessageStatus.read => (Icons.done_all, colors.primary),
      MessageStatus.failed => (Icons.error_outline, colors.error),
      MessageStatus.received => (null, color),
    };
    if (icon == null) return const SizedBox.shrink();
    return Icon(icon, size: 16, color: tint);
  }
}

/// Texto da situação de uma enviada.
String messageStatusText(AppLocalizations l10n, MessageStatus status) =>
    switch (status) {
      MessageStatus.pending => l10n.chatStatusPending,
      MessageStatus.sent => l10n.chatStatusSent,
      MessageStatus.delivered => l10n.chatStatusDelivered,
      MessageStatus.read => l10n.chatStatusRead,
      MessageStatus.failed => l10n.chatStatusFailed,
      MessageStatus.received => '',
    };

/// Por que uma enviada falhou, nas palavras da tela.
String failureText(AppLocalizations l10n, CoreError? failure) =>
    switch (failure) {
      CoreError.sessionNotFound => l10n.chatFailedNoSession,
      CoreError.untrustedIdentity => l10n.chatFailedIdentity,
      CoreError.unknownDestination => l10n.chatFailedUnknownAccount,
      CoreError.noAccount => l10n.chatFailedNoAccount,
      _ => l10n.chatFailedOther,
    };
