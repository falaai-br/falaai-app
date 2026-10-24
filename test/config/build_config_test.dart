import 'dart:convert';
import 'dart:io';

import 'package:falaai_app/config/build_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const gateway = 'wss://gw.falaai.test';
  const accounts = 'https://accounts.falaai.test';
  final root = base64Encode(testTrustRoot);

  BuildConfig parse({
    String environment = 'dev',
    String? trustRoot,
    String gatewayUrl = gateway,
    String accountsUrl = accounts,
  }) => BuildConfig.parse(
    environment: environment,
    trustRoot: trustRoot ?? root,
    gatewayUrl: gatewayUrl,
    accountsUrl: accountsUrl,
  );

  test('lê o ambiente, o trust root em base64 e o servidor', () {
    final config = parse();

    expect(config.environment, 'dev');
    expect(config.trustRoot, testTrustRoot);
    expect(config.gatewayUrl, gateway);
    expect(config.accountsUrl, accounts);
  });

  test('o servidor do core usa as URLs da build e as raízes da Mozilla', () {
    final server = parse().server;

    expect(server.gatewayUrl, gateway);
    expect(server.accountsUrl, accounts);
    expect(server.rootCertificates, isEmpty);
  });

  final invalid = <String, BuildConfig Function()>{
    'ambiente ausente': () => parse(environment: ''),
    'trust root ausente': () => parse(trustRoot: ''),
    'trust root fora de base64': () => parse(trustRoot: 'não é base64'),
    'trust root curto': () =>
        parse(trustRoot: base64Encode(testTrustRoot.sublist(1))),
    'trust root longo': () =>
        parse(trustRoot: base64Encode([...testTrustRoot, 0])),
    'gateway ausente': () => parse(gatewayUrl: ''),
    'accounts ausente': () => parse(accountsUrl: ''),
  };
  for (final MapEntry(key: name, value: build) in invalid.entries) {
    test('recusa build com $name', () {
      expect(build, throwsFormatException);
    });
  }

  test('sem dart-define a build não tem configuração', () {
    expect(BuildConfig.fromEnvironment, throwsFormatException);
  });

  test('o arquivo de dev declara as chaves que a build lê', () {
    final file = File('config/dev.json').readAsStringSync();
    final values = jsonDecode(file) as Map<String, Object?>;

    expect(
      values.keys,
      containsAll([
        'FALAAI_ENV',
        'FALAAI_TRUST_ROOT',
        'FALAAI_GATEWAY_URL',
        'FALAAI_ACCOUNTS_URL',
      ]),
    );
    expect(values['FALAAI_ENV'], 'dev');
  });

  test('em dev o servidor é o compose local, no loopback', () {
    final file = File('config/dev.json').readAsStringSync();
    final values = jsonDecode(file) as Map<String, Object?>;

    for (final key in ['FALAAI_GATEWAY_URL', 'FALAAI_ACCOUNTS_URL']) {
      expect(Uri.parse(values[key]! as String).host, '127.0.0.1', reason: key);
    }
  });

  test('o trust root de dev não entra no git: cada máquina gera o seu', () {
    final file = File('config/dev.json').readAsStringSync();
    final values = jsonDecode(file) as Map<String, Object?>;

    expect(values['FALAAI_TRUST_ROOT'], isEmpty);
    expect(
      File('.gitignore').readAsLinesSync(),
      contains('config/*.local.json'),
    );
  });
}
