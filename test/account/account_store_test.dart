import 'package:falaai_app/account/account_store.dart';
import 'package:falaai_app/account/pin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('aparelho novo: sem credenciais, sem nome, PIN não oferecido', () async {
    final account = await AccountStore(MemorySecretStore()).load();

    expect(account.device, isNull);
    expect(account.profileName, isNull);
    expect(account.pin, PinStatus.notOffered);
    expect(account.pinRemindAt, isNull);
  });

  test('guarda e relê credenciais, nome e PIN adiado', () async {
    final secrets = MemorySecretStore();
    final store = AccountStore(secrets);
    final remindAt = DateTime.utc(2026, 10, 25, 12);

    await store.saveDevice(testDevice);
    await store.saveProfileName('Ana');
    await store.savePin(PinStatus.deferred, remindAt: remindAt);
    final account = await AccountStore(secrets).load();

    expect(account.device?.aci, testDevice.aci);
    expect(account.device?.deviceId, testDevice.deviceId);
    expect(account.device?.token, testDevice.token);
    expect(account.profileName, 'Ana');
    expect(account.pin, PinStatus.deferred);
    expect(account.pinRemindAt?.isAtSameMomentAs(remindAt), isTrue);
  });

  test('o PIN em si nunca é guardado', () async {
    final secrets = MemorySecretStore();

    await AccountStore(secrets).savePin(PinStatus.set);

    expect(secrets.values[AccountStore.pinName], '{"status":"set"}');
  });

  test('valores malformados contam como ausentes', () async {
    final secrets = MemorySecretStore()
      ..values[AccountStore.deviceName] = '{"aci": 1}'
      ..values[AccountStore.pinName] = 'não é json';

    final account = await AccountStore(secrets).load();

    expect(account.device, isNull);
    expect(account.pin, PinStatus.notOffered);
  });
}
