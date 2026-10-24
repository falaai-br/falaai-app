// Grava num config/<ambiente>.local.json o trust root do falaai-signer de dev desta máquina.
//
// O keygen do compose do falaai-server (`make dev-up-signer` lá) gera as chaves de dev num
// volume local: cada máquina tem o seu trust root, então ele não entra no git e o
// config/dev.json o deixa vazio. O Makefile passa o .local.json depois do dev.json, e o valor
// dele vence.
//
// Uso: dart tool/dev_trust_root.dart --server-dir <checkout do falaai-server> --out <arquivo>
import 'dart:convert';
import 'dart:io';

/// Chave pública da libsignal: um byte de tipo e 32 de chave (o mesmo de `BuildConfig`).
const trustRootLength = 33;

/// Conteúdo do arquivo local para o trust root que o `falaai-server trust-root` imprimiu. Saída
/// que não é um trust root é erro, para não gravar uma build que o core recusaria ao abrir.
String localConfig(String output) {
  final trustRoot = output.trim();
  final List<int> key;
  try {
    key = base64Decode(trustRoot);
  } on FormatException {
    throw const FormatException('a saída do trust-root não é base64');
  }
  if (key.length != trustRootLength) {
    throw FormatException(
      'trust root com ${key.length} bytes; esperado $trustRootLength',
    );
  }
  return '${const JsonEncoder.withIndent('  ').convert({'FALAAI_TRUST_ROOT': trustRoot})}\n';
}

Future<void> main(List<String> args) async {
  final options = <String, String>{
    for (var i = 0; i + 1 < args.length; i += 2)
      args[i].replaceFirst('--', ''): args[i + 1],
  };
  final serverDir = options['server-dir'];
  final out = options['out'];
  if (serverDir == null || out == null) {
    stderr.writeln(
      'uso: dart tool/dev_trust_root.dart --server-dir <dir> --out <arquivo>',
    );
    exit(64);
  }
  final result = await Process.run('docker', [
    'compose',
    'exec',
    '-T',
    'server',
    '/falaai-server',
    'trust-root',
  ], workingDirectory: serverDir);
  if (result.exitCode != 0) {
    stderr
      ..write(result.stderr)
      ..writeln(
        'trust-root falhou em $serverDir: suba o servidor com make dev-up-signer',
      );
    exit(1);
  }
  await File(out).writeAsString(localConfig(result.stdout as String));
  stdout.writeln('trust root de dev gravado em $out');
}
