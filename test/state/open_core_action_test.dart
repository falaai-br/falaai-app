import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('o estado começa com o core abrindo', () {
    final store = createStore(Dependencies(openCore: () async => FakeCore()));

    expect(store.state.core, CoreStatus.starting);
  });

  test('core aberto: estado pronto e handle nas dependências', () async {
    final core = FakeCore();
    final deps = Dependencies(openCore: () async => core);
    final store = createStore(deps);

    await store.dispatchAndWait(OpenCoreAction());

    expect(store.state.core, CoreStatus.ready);
    expect(deps.core, same(core));
  });

  test('falha ao abrir: estado de erro e sem handle', () async {
    final deps = Dependencies(
      openCore: () async => throw StateError('chave errada'),
    );
    final store = createStore(deps);

    await store.dispatchAndWait(OpenCoreAction());

    expect(store.state.core, CoreStatus.failed);
    expect(deps.core, isNull);
  });
}
