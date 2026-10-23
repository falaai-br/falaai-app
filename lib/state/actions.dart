import 'package:async_redux/async_redux.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Serviços injetados na store, lidos pelas actions em [AppAction.deps].
class Dependencies {
  Dependencies({required this.openCore});

  /// Abre o falaai-core sobre o banco local do aparelho.
  final Future<FalaaiCore> Function() openCore;

  /// Handle do core depois de [OpenCoreAction]. Fica fora do [AppState]: é um recurso nativo,
  /// não estado da UI.
  FalaaiCore? core;
}

/// Store do app com o estado inicial.
Store<AppState> createStore(Dependencies dependencies) => Store<AppState>(
  initialState: const AppState(),
  dependencies: (_) => dependencies,
);

/// Base das actions do app.
abstract class AppAction extends ReduxAction<AppState> {
  Dependencies get deps => store.dependencies! as Dependencies;
}

/// Abre o falaai-core uma vez, no início do app.
class OpenCoreAction extends AppAction {
  @override
  Future<AppState?> reduce() async {
    try {
      deps.core = await deps.openCore();
    } catch (_) {
      // O detalhe do erro não vai para log: pode carregar caminho do banco ou dado do core.
      return state.copyWith(core: CoreStatus.failed);
    }
    return state.copyWith(core: CoreStatus.ready);
  }
}

/// Acesso ao estado nos widgets.
extension AppStateContext on BuildContext {
  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);
}
