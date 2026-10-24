import 'package:async_redux/async_redux.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/widgets.dart';

import '../account/account_store.dart';
import '../account/accounts_api.dart';
import '../account/registration.dart';
import '../core/database_key.dart';
import 'app_state.dart';

/// Serviços injetados na store, lidos pelas actions em [AppAction.deps].
class Dependencies {
  /// [accounts] cria o cliente do `accounts` no primeiro uso: a URL vem da configuração da
  /// build, lida só depois do primeiro frame. [now] é o relógio; os testes injetam outro.
  Dependencies({
    required this.openCore,
    required SecretStore secrets,
    required AccountsApi Function() accounts,
    DateTime Function()? now,
  }) : account = AccountStore(secrets),
       _accounts = accounts,
       now = now ?? DateTime.now;

  /// Abre o falaai-core sobre o banco local do aparelho.
  final Future<FalaaiCore> Function() openCore;

  /// Conta guardada no aparelho.
  final AccountStore account;

  final AccountsApi Function() _accounts;

  /// Cliente do `accounts`.
  late final AccountsApi accounts = _accounts();

  final DateTime Function() now;

  /// Registro deste aparelho, criado na primeira tentativa e mantido entre as seguintes.
  AccountRegistration? registration;

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

  /// O estado agora, sem reconstruir o widget quando ele muda (para callbacks).
  AppState read() => getRead<AppState>();
}
