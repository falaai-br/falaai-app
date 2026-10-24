import 'dart:convert';
import 'dart:typed_data';

import 'package:falaai_core/falaai_core.dart';

/// Configuração do ambiente, embutida na build por
/// `--dart-define-from-file=config/<ambiente>.json` (o Makefile passa o arquivo). Nada daqui é
/// baixado em tempo de execução: trocar de ambiente é trocar de build.
class BuildConfig {
  const BuildConfig({
    required this.environment,
    required this.trustRoot,
    required this.gatewayUrl,
    required this.accountsUrl,
  });

  /// A configuração que veio na build.
  factory BuildConfig.fromEnvironment() => BuildConfig.parse(
    environment: const String.fromEnvironment('FALAAI_ENV'),
    trustRoot: const String.fromEnvironment('FALAAI_TRUST_ROOT'),
    gatewayUrl: const String.fromEnvironment('FALAAI_GATEWAY_URL'),
    accountsUrl: const String.fromEnvironment('FALAAI_ACCOUNTS_URL'),
  );

  /// Lê os valores do arquivo de ambiente. [trustRoot] vem em base64. Valor ausente ou
  /// malformado é erro: sem trust root o core não aceita nenhum certificado de remetente. O
  /// esquema e o formato das URLs quem confere é o core, ao conectar.
  factory BuildConfig.parse({
    required String environment,
    required String trustRoot,
    required String gatewayUrl,
    required String accountsUrl,
  }) {
    if (environment.isEmpty) {
      throw const FormatException('FALAAI_ENV ausente na build');
    }
    if (gatewayUrl.isEmpty) {
      throw const FormatException('FALAAI_GATEWAY_URL ausente na build');
    }
    if (accountsUrl.isEmpty) {
      throw const FormatException('FALAAI_ACCOUNTS_URL ausente na build');
    }
    return BuildConfig(
      environment: environment,
      trustRoot: parseTrustRoot(trustRoot),
      gatewayUrl: gatewayUrl,
      accountsUrl: accountsUrl,
    );
  }

  /// Chave pública da libsignal: um byte de tipo e 32 de chave.
  static const trustRootLength = 33;

  /// Decodifica o trust root em base64 e confere o tamanho.
  static Uint8List parseTrustRoot(String trustRoot) {
    final Uint8List key;
    try {
      key = base64Decode(trustRoot);
    } on FormatException {
      throw const FormatException('FALAAI_TRUST_ROOT não é base64');
    }
    if (key.length != trustRootLength) {
      throw const FormatException('FALAAI_TRUST_ROOT ausente ou malformado');
    }
    return key;
  }

  /// Nome do ambiente (`dev`, por exemplo).
  final String environment;

  /// Chave pública raiz do servidor neste ambiente. Os certificados de remetente que o core
  /// aceita encadeiam até ela.
  final Uint8List trustRoot;

  /// Base do gateway, sem caminho (`wss://…`; `ws://` só no loopback).
  final String gatewayUrl;

  /// Base do `accounts`, sem caminho (`https://…`; `http://` só no loopback).
  final String accountsUrl;

  /// Servidor para [FalaaiCore.connect]. Sem certificados raiz próprios: o core confia nas
  /// raízes da Mozilla.
  ServerConfig get server => ServerConfig(
    gatewayUrl: gatewayUrl,
    accountsUrl: accountsUrl,
    rootCertificates: const [],
  );
}
