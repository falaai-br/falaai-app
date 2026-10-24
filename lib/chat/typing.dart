import 'package:falaai_core/falaai_core.dart';

/// Um contato começou ou parou de digitar.
class TypingEvent {
  const TypingEvent({required this.from, required this.typing});

  final DeviceAddress from;
  final bool typing;
}

/// Por onde os avisos de digitação vão e de onde vêm. O relay efêmero é do gateway
/// (blueprint 03), que ainda não tem o frame; até lá, [NoTypingSignals] não envia nem recebe,
/// e a UI segue pronta para quando houver.
abstract interface class TypingSignals {
  /// Avisos dos contatos.
  Stream<TypingEvent> incoming();

  /// Avisa [peer] que este usuário está ([typing]) ou parou de digitar.
  Future<void> send(DeviceAddress peer, {required bool typing});
}

/// [TypingSignals] sem transporte.
class NoTypingSignals implements TypingSignals {
  const NoTypingSignals();

  @override
  Stream<TypingEvent> incoming() => const Stream.empty();

  @override
  Future<void> send(DeviceAddress peer, {required bool typing}) async {}
}

/// Sem aviso novo por este tempo, o indicador de digitação some.
const typingTimeout = Duration(seconds: 5);

/// O compositor repete o aviso de digitação no máximo a cada este intervalo.
const typingRefresh = Duration(seconds: 3);
