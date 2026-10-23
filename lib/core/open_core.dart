import 'dart:io';

import 'package:falaai_core/falaai_core.dart';

import 'database_key.dart';

/// Nome do banco local do core no diretório de dados do app.
const databaseFileName = 'falaai.db';

/// Abre o falaai-core sobre o banco em [dataDir] com a chave de [secrets]. A ponte
/// (`FalaaiCoreLib.init`) já tem de estar inicializada.
Future<FalaaiCore> openFalaaiCore({
  required SecretStore secrets,
  required Future<Directory> Function() dataDir,
}) async {
  final dir = await dataDir();
  final key = await DatabaseKey(secrets).loadOrCreate();
  try {
    return await FalaaiCore.open(
      dbPath: '${dir.path}/$databaseFileName',
      dbKey: key,
    );
  } finally {
    // Melhor esforço: o GC pode ter copiado os bytes, mas esta cópia não fica viva.
    key.fillRange(0, key.length, 0);
  }
}
