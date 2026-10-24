import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../account/pin.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../state/actions.dart';
import '../../state/app_state.dart';
import '../../state/onboarding_actions.dart';
import 'onboarding_page.dart';

/// PIN de registro, oferecido no fim do cadastro e pelo lembrete. Pode ser adiado.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _matches => _pin.text == _confirmation.text;

  Future<void> _create() async {
    await context.dispatchAndWait(SetPinAction(_pin.text));
    if (mounted && context.read().account.pin == PinStatus.set) {
      context.go(Routes.home);
    }
  }

  Future<void> _later() async {
    await context.dispatchAndWait(DeferPinAction());
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = context.select((state) => state.onboarding.error);
    final busy = context.isWaiting([SetPinAction, DeferPinAction]);
    final mismatch = _confirmation.text.isNotEmpty && !_matches;
    return OnboardingPage(
      title: l10n.pinTitle,
      message: l10n.pinMessage,
      children: [
        _PinField(
          controller: _pin,
          label: l10n.pinLabel(minPinLength),
          autofocus: true,
          enabled: !busy,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        _PinField(
          controller: _confirmation,
          label: l10n.pinConfirmLabel,
          enabled: !busy,
          errorText: mismatch
              ? l10n.pinMismatch
              : error == null || busy
              ? null
              : error == OnboardingError.unavailable
              ? l10n.pinUnavailable
              : onboardingErrorText(l10n, error),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: l10n.pinCreate,
          busy: busy,
          onPressed: isValidPin(_pin.text) && _matches ? _create : null,
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: busy ? null : _later, child: Text(l10n.pinLater)),
        const SizedBox(height: 8),
        Text(
          l10n.pinLaterHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.autofocus = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback onChanged;
  final bool autofocus;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.number,
      maxLength: maxPinLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
