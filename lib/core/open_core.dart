import 'dart:io';

import 'package:falaai_core/falaai_core.dart';

import 'database_key.dart';
import 'sender_certificate.dart';

/// Nome do banco local do core no diretório de dados do app.
const databaseFileName = 'falaai.db';

/// Abre o falaai-core sobre o banco em [dataDir] com a chave de [secrets] e reentrega o
/// certificado de remetente guardado. [trustRoot] é o da build (`BuildConfig`). A ponte
/// (`FalaaiCoreLib.init`) já tem de estar inicializada.
Future<FalaaiCore> openFalaaiCore({
  required SecretStore secrets,
  required Future<Directory> Function() dataDir,
  required List<int> trustRoot,
}) async {
  final dir = await dataDir();
  final key = await DatabaseKey(secrets).loadOrCreate();
  final FalaaiCore core;
  try {
    core = await FalaaiCore.open(
      dbPath: '${dir.path}/$databaseFileName',
      dbKey: key,
      trustRoot: trustRoot,
    );
  } finally {
    // Melhor esforço: o GC pode ter copiado os bytes, mas esta cópia não fica viva.
    key.fillRange(0, key.length, 0);
  }
  await SenderCertificates(secrets).restore(core);
  return core;
}
