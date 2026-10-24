import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/onboarding_actions.dart';
import 'onboarding_page.dart';

/// Maior nome aceito, em caracteres.
const maxProfileNameLength = 40;

/// Terceira tela do cadastro: o nome do perfil.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  void _submit() {
    if (_valid) context.dispatch(SaveProfileNameAction(_name.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingPage(
      title: l10n.nameTitle,
      message: l10n.nameMessage,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          maxLength: maxProfileNameLength,
          decoration: InputDecoration(labelText: l10n.nameLabel),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: l10n.continueButton,
          busy: context.isWaiting(SaveProfileNameAction),
          onPressed: _valid ? _submit : null,
        ),
      ],
    );
  }
}
