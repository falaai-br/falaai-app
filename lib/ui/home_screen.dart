import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../router.dart';
import '../state/actions.dart';
import '../state/app_state.dart';
import '../state/onboarding_actions.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          if (pinReminder && core == CoreStatus.ready) const _PinReminder(),
          Expanded(
            child: Center(
              child: switch (core) {
                CoreStatus.failed => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.coreFailed, textAlign: TextAlign.center),
                ),
                CoreStatus.starting => Semantics(
                  label: l10n.coreStarting,
                  child: const CircularProgressIndicator(),
                ),
                CoreStatus.ready when loading => Semantics(
                  label: l10n.coreStarting,
                  child: const CircularProgressIndicator(),
                ),
                CoreStatus.ready => Text(l10n.homeEmpty),
              },
            ),
          ),
        ],
      ),
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
