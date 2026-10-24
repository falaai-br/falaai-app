/// Celular brasileiro: DDD de 11 a 99, sem zero, e nove dígitos começando por 9.
final _brazilianMobile = RegExp(r'^[1-9][1-9]9\d{8}$');

/// Converte o que a pessoa digitou (`(11) 91234-5678`, `11912345678` ou `+55 11 91234-5678`)
/// no E.164 que o `accounts` exige (`+5511912345678`). Devolve `null` se não for um celular
/// brasileiro: o MVP só registra números do Brasil, e o código chega por SMS.
String? parseBrazilianMobile(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  final national = digits.length == 13 && digits.startsWith('55')
      ? digits.substring(2)
      : digits;
  if (!_brazilianMobile.hasMatch(national)) return null;
  return '+55$national';
}

/// Mostra um celular em E.164 de [parseBrazilianMobile] como `(11) 91234-5678`.
String formatBrazilianMobile(String e164) {
  final national = e164.substring(3);
  return '(${national.substring(0, 2)}) '
      '${national.substring(2, 7)}-${national.substring(7)}';
}
