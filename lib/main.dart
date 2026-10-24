import 'dart:io';

import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'account/accounts_api.dart';
import 'app.dart';
import 'config/build_config.dart';
import 'core/database_key.dart';
import 'core/open_core.dart';
import 'state/actions.dart';
import 'state/onboarding_actions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = createStore(
    Dependencies(
      openCore: _openCore,
      secrets: _secrets,
      accounts: () => HttpAccountsApi(
        baseUrl: BuildConfig.fromEnvironment().accountsUrl,
        platform: Platform.isIOS ? 'ios' : 'android',
      ),
    ),
  );
  // O core abre depois do primeiro frame; a UI mostra o progresso pelo estado. A conta
  // guardada decide se o app abre no cadastro.
  store.dispatch(OpenCoreAction());
  store.dispatch(LoadAccountAction());
  runApp(FalaAiApp(store: store));
}

final _secrets = DeviceSecretStore();

Future<FalaaiCore> _openCore() async {
  // Antes da ponte: sem trust root na build, o core não abre.
  final config = BuildConfig.fromEnvironment();
  await FalaaiCoreLib.init();
  return openFalaaiCore(
    secrets: _secrets,
    dataDir: getApplicationSupportDirectory,
    trustRoot: config.trustRoot,
  );
}
