import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'config/build_config.dart';
import 'core/database_key.dart';
import 'core/open_core.dart';
import 'state/actions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = createStore(Dependencies(openCore: _openCore));
  // O core abre depois do primeiro frame; a UI mostra o progresso pelo estado.
  store.dispatch(OpenCoreAction());
  runApp(FalaAiApp(store: store));
}

Future<FalaaiCore> _openCore() async {
  // Antes da ponte: sem trust root na build, o core não abre.
  final config = BuildConfig.fromEnvironment();
  await FalaaiCoreLib.init();
  return openFalaaiCore(
    secrets: DeviceSecretStore(),
    dataDir: getApplicationSupportDirectory,
    trustRoot: config.trustRoot,
  );
}
