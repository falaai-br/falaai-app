import 'package:falaai_app/account/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBrazilianMobile', () {
    const cases = <(String, String?)>[
      ('11912345678', '+5511912345678'),
      ('(11) 91234-5678', '+5511912345678'),
      ('+55 11 91234-5678', '+5511912345678'),
      ('5511912345678', '+5511912345678'),
      (' 21 98765 4321 ', '+5521987654321'),
      // Fixo, sem o 9: não recebe SMS.
      ('1132345678', null),
      // DDD com zero.
      ('01912345678', null),
      ('10912345678', null),
      // Curto e longo demais.
      ('1191234567', null),
      ('119123456789', null),
      // Outro país.
      ('+1 415 555 0100', null),
      ('', null),
    ];
    for (final (input, expected) in cases) {
      test('"$input" -> $expected', () {
        expect(parseBrazilianMobile(input), expected);
      });
    }
  });

  test('formatBrazilianMobile mostra DDD e número separados', () {
    expect(formatBrazilianMobile('+5511912345678'), '(11) 91234-5678');
  });
}
