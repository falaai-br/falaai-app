import 'package:falaai_app/account/account_store.dart';
import 'package:falaai_app/account/accounts_api.dart';
import 'package:falaai_app/account/registration.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late RecordingCore core;
  late FakeAccountsApi api;
  late MemorySecretStore secrets;
  late AccountRegistration registration;

  setUp(() {
    core = RecordingCore();
    api = FakeAccountsApi();
    secrets = MemorySecretStore();
    registration = AccountRegistration(core, api, AccountStore(secrets));
  });

  Future<DeviceCredentials?> stored() => AccountStore(secrets).device();

  test(
    'registra, gera as chaves, grava o endereço, publica e só então guarda',
    () async {
      final device = await registration.register(
        phone: '+5511912345678',
        code: '123456',
      );

      expect(api.registrations.single, (
        phone: '+5511912345678',
        code: '123456',
      ));
      expect(core.calls, ['generateAccountKeys', 'setLocalAddress']);
      expect(core.localAddress, testDevice.address);
      expect(api.calls, ['register', 'uploadKeys']);
      expect(api.uploads.single.device, same(device));
      expect(api.uploads.single.keys, same(testAccountKeys));
      expect((await stored())?.token, testDevice.token);
    },
  );

  test('código recusado: nada é gerado nem guardado', () async {
    api.registerErrors.add(AccountsError.invalidCode);

    await expectLater(
      registration.register(phone: '+5511912345678', code: '000000'),
      throwsA(AccountsError.invalidCode),
    );

    expect(core.calls, isEmpty);
    expect(await stored(), isNull);
  });

  test(
    'publicação falhou: não conta como registrado e a nova tentativa reaproveita as chaves',
    () async {
      api.uploadErrors.add(AccountsError.network);

      await expectLater(
        registration.register(phone: '+5511912345678', code: '123456'),
        throwsA(AccountsError.network),
      );
      expect(await stored(), isNull);

      await registration.register(phone: '+5511912345678', code: '123456');

      expect(core.generatedKeys, 1, reason: 'o core gera as chaves uma vez só');
      expect(api.uploads.single.keys, same(testAccountKeys));
      expect(await stored(), isNotNull);
    },
  );

  test(
    'chaves já geradas em outra sessão: erro do core, sem registro',
    () async {
      core.keyErrors.add(CoreError.accountExists);

      await expectLater(
        registration.register(phone: '+5511912345678', code: '123456'),
        throwsA(CoreError.accountExists),
      );
      expect(api.uploads, isEmpty);
      expect(await stored(), isNull);
    },
  );
}
