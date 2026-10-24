import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/dev_trust_root.dart';
import '../support/fakes.dart';

void main() {
  final root = base64Encode(testTrustRoot);

  test('grava só o trust root, sem a quebra de linha da saída', () {
    final values = jsonDecode(localConfig('$root\n')) as Map<String, Object?>;

    expect(values, {'FALAAI_TRUST_ROOT': root});
  });

  test('o tamanho é o que a build aceita', () {
    expect(trustRootLength, 33);
  });

  for (final (name, output) in [
    ('saída vazia', ''),
    ('mensagem de erro', 'Error: service "server" is not running'),
    ('chave curta', base64Encode(testTrustRoot.sublist(1))),
  ]) {
    test('recusa $name', () {
      expect(() => localConfig(output), throwsFormatException);
    });
  }
}
