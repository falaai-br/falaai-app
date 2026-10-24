import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'contact.dart';

/// Pede o id da conta (UUID) para abrir uma conversa. Serve ao dev e à demo até o convite por
/// link, QR e username (fla-wyh). Devolve o ACI, ou `null` se cancelou.
Future<String?> showNewConversationDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _NewConversationDialog(),
    );

class _NewConversationDialog extends StatefulWidget {
  const _NewConversationDialog();

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final _id = TextEditingController();
  var _invalid = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  void _open() {
    final aci = parseAci(_id.text);
    if (aci == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(aci);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.chatNew),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chatNewMessage),
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.chatNewLabel,
              errorText: _invalid ? l10n.chatNewInvalid : null,
            ),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _open(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _open, child: Text(l10n.chatNewOpen)),
      ],
    );
  }
}
