import 'dart:convert';
import 'dart:typed_data';

/// Configuração do ambiente, embutida na build por
/// `--dart-define-from-file=config/<ambiente>.json` (o Makefile passa o arquivo). Nada daqui é
/// baixado em tempo de execução: trocar de ambiente é trocar de build.
class BuildConfig {
  const BuildConfig({required this.environment, required this.trustRoot});

  /// A configuração que veio na build.
  factory BuildConfig.fromEnvironment() => BuildConfig.parse(
    environment: const String.fromEnvironment('FALAAI_ENV'),
    trustRoot: const String.fromEnvironment('FALAAI_TRUST_ROOT'),
  );

  /// Lê os valores do arquivo de ambiente. [trustRoot] vem em base64. Valor ausente ou
  /// malformado é erro: sem trust root o core não aceita nenhum certificado de remetente.
  factory BuildConfig.parse({
    required String environment,
    required String trustRoot,
  }) {
    if (environment.isEmpty) {
      throw const FormatException('FALAAI_ENV ausente na build');
    }
    final Uint8List key;
    try {
      key = base64Decode(trustRoot);
    } on FormatException {
      throw const FormatException('FALAAI_TRUST_ROOT não é base64');
    }
    if (key.length != trustRootLength) {
      throw const FormatException('FALAAI_TRUST_ROOT ausente ou malformado');
    }
    return BuildConfig(environment: environment, trustRoot: key);
  }

  /// Chave pública da libsignal: um byte de tipo e 32 de chave.
  static const trustRootLength = 33;

  /// Nome do ambiente (`dev`, por exemplo).
  final String environment;

  /// Chave pública raiz do servidor neste ambiente. Os certificados de remetente que o core
  /// aceita encadeiam até ela.
  final Uint8List trustRoot;
}
