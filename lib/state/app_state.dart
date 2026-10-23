import 'package:flutter/foundation.dart';

/// Estado do falaai-core no aparelho.
enum CoreStatus {
  /// Abrindo o banco local cifrado.
  starting,

  /// Banco aberto; o core aceita chamadas.
  ready,

  /// O banco não abriu (chave ausente ou errada, biblioteca nativa ausente).
  failed,
}

/// Estado único do app (Async Redux). Imutável: os reducers devolvem cópias.
@immutable
class AppState {
  const AppState({this.core = CoreStatus.starting});

  final CoreStatus core;

  AppState copyWith({CoreStatus? core}) => AppState(core: core ?? this.core);

  @override
  bool operator ==(Object other) => other is AppState && other.core == core;

  @override
  int get hashCode => core.hashCode;
}
