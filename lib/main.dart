import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
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
  await FalaaiCoreLib.init();
  return openFalaaiCore(
    secrets: DeviceSecretStore(),
    dataDir: getApplicationSupportDirectory,
  );
}
