// Roda em aparelho ou emulador conectado: make test-device. Fora dos hooks.
// Usa a biblioteca nativa do falaai-core empacotada no app.
import 'dart:io';

import 'package:falaai_app/app.dart';
import 'package:falaai_app/core/open_core.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/app_state.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dataDir;

  setUpAll(FalaaiCoreLib.init);
  setUp(() async => dataDir = await Directory.systemTemp.createTemp('falaai'));
  tearDown(() => dataDir.delete(recursive: true));

  Future<FalaaiCore> open(MemorySecretStore secrets) => openFalaaiCore(
    secrets: secrets,
    dataDir: () async => dataDir,
    trustRoot: testTrustRoot,
  );

  testWidgets('o app abre o core nativo e mostra a lista vazia', (
    tester,
  ) async {
    final secrets = MemorySecretStore();
    final store = createStore(Dependencies(openCore: () => open(secrets)));
    store.dispatch(OpenCoreAction());
    await tester.pumpWidget(FalaAiApp(store: store));

    await tester.pumpAndSettle();

    expect(store.state.core, CoreStatus.ready);
    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
  });

  testWidgets('o core gera as chaves da conta e reabre o banco cifrado', (
    tester,
  ) async {
    final secrets = MemorySecretStore();

    final keys = await (await open(secrets)).generateAccountKeys();
    expect(keys.identityKey, isNotEmpty);
    expect(keys.preKeys, isNotEmpty);

    // Mesmo banco, mesma chave: as chaves da conta já existem.
    await expectLater(
      (await open(secrets)).generateAccountKeys(),
      throwsA(CoreError.accountExists),
    );
  });

  testWidgets('o core nativo recusa trust root malformado', (tester) async {
    await expectLater(
      openFalaaiCore(
        secrets: MemorySecretStore(),
        dataDir: () async => dataDir,
        trustRoot: testTrustRoot.sublist(0, 10),
      ),
      throwsA(CoreError.invalidKey),
    );
  });
}
