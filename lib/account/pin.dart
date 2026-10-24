/// Onde está o PIN de registro deste aparelho.
enum PinStatus {
  /// Ainda não foi oferecido: o onboarding termina oferecendo.
  notOffered,

  /// A pessoa adiou; o app lembra depois de [pinReminderInterval].
  deferred,

  /// Criado no servidor.
  set,
}

/// Quanto tempo depois de adiar o PIN o app volta a oferecê-lo.
const pinReminderInterval = Duration(days: 1);

/// Tamanho mínimo do PIN, em dígitos.
const minPinLength = 4;

/// Tamanho máximo do PIN, em dígitos.
const maxPinLength = 20;

final _pin = RegExp('^\\d{$minPinLength,$maxPinLength}\$');

/// Se [pin] serve como PIN de registro: só números, de [minPinLength] a [maxPinLength].
bool isValidPin(String pin) => _pin.hasMatch(pin);
