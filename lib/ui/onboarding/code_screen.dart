import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../account/accounts_api.dart';
import '../../account/phone_number.dart';
import '../../l10n/app_localizations.dart';
import '../../state/actions.dart';
import '../../state/app_state.dart';
import '../../state/onboarding_actions.dart';
import 'onboarding_page.dart';

/// Segunda tela do cadastro: o código do SMS. Confirmar registra o aparelho.
class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _complete => _code.text.length == verificationCodeLength;

  void _submit() {
    if (_complete) context.dispatch(VerifyCodeAction(_code.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = context.select((state) => state.onboarding.phone);
    final error = context.select((state) => state.onboarding.error);
    // O registro usa o core: enquanto ele abre, o botão espera; se não abriu, não há registro.
    final core = context.select((state) => state.core);
    final busy = context.isWaiting(VerifyCodeAction);
    return OnboardingPage(
      title: l10n.codeTitle,
      message: l10n.codeMessage(
        phone == null ? '' : formatBrazilianMobile(phone),
      ),
      children: [
        TextField(
          controller: _code,
          autofocus: true,
          enabled: !busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: verificationCodeLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.codeLabel(verificationCodeLength),
            errorText: core == CoreStatus.failed
                ? l10n.coreFailed
                : error == null || busy
                ? null
                : onboardingErrorText(l10n, error),
            errorMaxLines: 3,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: l10n.codeConfirm,
          busy: busy || core == CoreStatus.starting,
          onPressed: _complete && core == CoreStatus.ready ? _submit : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : () => context.dispatch(EditPhoneAction()),
          child: Text(l10n.codeEditPhone),
        ),
      ],
    );
  }
}
