import 'dart:convert';
import 'dart:io';

import 'package:falaai_app/config/build_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('lê o ambiente e o trust root em base64', () {
    final config = BuildConfig.parse(
      environment: 'dev',
      trustRoot: base64Encode(testTrustRoot),
    );

    expect(config.environment, 'dev');
    expect(config.trustRoot, testTrustRoot);
  });

  final invalid = {
    'ambiente ausente': (env: '', root: base64Encode(testTrustRoot)),
    'trust root ausente': (env: 'dev', root: ''),
    'trust root fora de base64': (env: 'dev', root: 'não é base64'),
    'trust root curto': (
      env: 'dev',
      root: base64Encode(testTrustRoot.sublist(1)),
    ),
    'trust root longo': (env: 'dev', root: base64Encode([...testTrustRoot, 0])),
  };
  for (final MapEntry(key: name, value: input) in invalid.entries) {
    test('recusa build com $name', () {
      expect(
        () => BuildConfig.parse(environment: input.env, trustRoot: input.root),
        throwsFormatException,
      );
    });
  }

  test('sem dart-define a build não tem configuração', () {
    expect(BuildConfig.fromEnvironment, throwsFormatException);
  });

  test('o arquivo de dev declara as chaves que a build lê', () {
    final file = File('config/dev.json').readAsStringSync();
    final values = jsonDecode(file) as Map<String, Object?>;

    expect(values.keys, containsAll(['FALAAI_ENV', 'FALAAI_TRUST_ROOT']));
    expect(values['FALAAI_ENV'], 'dev');
  });
}
