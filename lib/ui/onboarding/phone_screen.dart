import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../state/actions.dart';
import '../../state/app_state.dart';
import '../../state/onboarding_actions.dart';
import 'onboarding_page.dart';

/// Primeira tela do cadastro: o celular.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() => context.dispatch(SubmitPhoneAction(_phone.text));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = context.select((state) => state.onboarding.error);
    return OnboardingPage(
      title: l10n.phoneTitle,
      message: l10n.phoneMessage,
      children: [
        TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d\s()+-]')),
          ],
          decoration: InputDecoration(
            labelText: l10n.phoneLabel,
            hintText: l10n.phoneHint,
            prefixText: '+55 ',
            errorText: error == OnboardingError.invalidPhone
                ? l10n.phoneInvalid
                : null,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: l10n.continueButton,
          busy: false,
          onPressed: _submit,
        ),
        const SizedBox(height: 32),
        Text(
          l10n.onboardingPrivacy,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
