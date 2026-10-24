import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Layout comum das telas do cadastro: título, explicação e o conteúdo, rolando acima do
/// teclado.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.message,
    required this.children,
  });

  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(title, style: text.headlineSmall),
              ),
              const SizedBox(height: 12),
              Text(message, style: text.bodyLarge),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão principal do cadastro. Desligado sem [onPressed]; com [busy], mostra o progresso no
/// lugar do texto.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: AppLocalizations.of(context).waiting,
              ),
            )
          : Text(label),
    );
  }
}

/// Texto de cada falha do cadastro.
String onboardingErrorText(AppLocalizations l10n, OnboardingError error) =>
    switch (error) {
      OnboardingError.invalidPhone => l10n.phoneInvalid,
      OnboardingError.invalidCode => l10n.codeInvalid,
      OnboardingError.rateLimited => l10n.errorRateLimited,
      OnboardingError.network => l10n.errorNetwork,
      OnboardingError.unavailable => l10n.errorUnavailable,
      OnboardingError.failed => l10n.errorFailed,
    };
