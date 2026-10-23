import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/actions.dart';
import '../state/app_state.dart';

/// Tela inicial: a lista de conversas, depois que o core abre.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = context.select((state) => state.core);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: switch (core) {
          CoreStatus.starting => Semantics(
            label: l10n.coreStarting,
            child: const CircularProgressIndicator(),
          ),
          CoreStatus.ready => Text(l10n.homeEmpty),
          CoreStatus.failed => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.coreFailed, textAlign: TextAlign.center),
          ),
        },
      ),
    );
  }
}
