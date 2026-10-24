import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';
import 'router.dart';
import 'state/app_state.dart';

/// Raiz do app: store, rotas, tema e textos em pt-BR.
class FalaAiApp extends StatefulWidget {
  const FalaAiApp({super.key, required this.store});

  final Store<AppState> store;

  @override
  State<FalaAiApp> createState() => _FalaAiAppState();
}

class _FalaAiAppState extends State<FalaAiApp> {
  late final _refresh = OnboardingRefresh(widget.store);
  late final GoRouter _router = createRouter(widget.store, _refresh);

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: widget.store,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF00897B)),
        // pt-BR é o idioma único no MVP; o ARB é 'pt' e as datas e números seguem o Brasil.
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}
