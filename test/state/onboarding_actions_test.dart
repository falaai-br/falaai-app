import 'dart:convert';

import 'package:async_redux/async_redux.dart';

import 'package:falaai_app/account/account_store.dart';
import 'package:falaai_app/account/accounts_api.dart';
import 'package:falaai_app/account/pin.dart';
import 'package:falaai_app/state/actions.dart';
import 'package:falaai_app/state/app_state.dart';
import 'package:falaai_app/state/onboarding_actions.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 9);

  late MemorySecretStore secrets;
  late FakeAccountsApi api;
  late RecordingCore core;

  setUp(() {
    secrets = MemorySecretStore();
    api = FakeAccountsApi();
    core = RecordingCore();
  });

  Future<Store<AppState>> store() async {
    final store = createStore(
      testDependencies(
        openCore: () async => core,
        secrets: secrets,
        accounts: api,
        now: () => now,
      ),
    );
    await store.dispatchAndWait(OpenCoreAction());
    await store.dispatchAndWait(LoadAccountAction());
    return store;
  }

  void storeDevice() =>
      secrets.values[AccountStore.deviceName] = jsonEncode(testDevice.toJson());

  group('LoadAccountAction', () {
    test('aparelho novo: sem registro', () async {
      final account = (await store()).state.account;

      expect(account.status, AccountStatus.unregistered);
      expect(account.pin, PinStatus.notOffered);
      expect(account.pinReminderDue, isFalse);
    });

    test('aparelho registrado: nome e PIN guardados', () async {
      storeDevice();
      secrets.values[AccountStore.profileNameName] = 'Ana';
      await AccountStore(secrets).savePin(PinStatus.set);

      final account = (await store()).state.account;

      expect(account.status, AccountStatus.registered);
      expect(account.profileName, 'Ana');
      expect(account.pin, PinStatus.set);
    });

    const reminders = <(Duration, bool)>[
      (Duration(hours: 1), false),
      (Duration.zero, true),
      (Duration(hours: -1), true),
    ];
    for (final (untilReminder, due) in reminders) {
      test('PIN adiado, lembrete em $untilReminder: lembrar = $due', () async {
        storeDevice();
        await AccountStore(
          secrets,
        ).savePin(PinStatus.deferred, remindAt: now.add(untilReminder));

        expect((await store()).state.account.pinReminderDue, due);
      });
    }
  });

  group('SubmitPhoneAction', () {
    test('celular válido: segue para o código em E.164', () async {
      final s = await store();

      s.dispatch(SubmitPhoneAction('(11) 91234-5678'));

      expect(s.state.onboarding.phone, '+5511912345678');
      expect(s.state.onboarding.error, isNull);
    });

    test('número inválido: fica na tela com o erro', () async {
      final s = await store();

      s.dispatch(SubmitPhoneAction('1234'));

      expect(s.state.onboarding.phone, isNull);
      expect(s.state.onboarding.error, OnboardingError.invalidPhone);
    });

    test('EditPhoneAction volta ao número', () async {
      final s = await store();
      s.dispatch(SubmitPhoneAction('11912345678'));

      s.dispatch(EditPhoneAction());

      expect(s.state.onboarding, const OnboardingState());
    });
  });

  group('VerifyCodeAction', () {
    test('registra o aparelho e limpa o cadastro em andamento', () async {
      final s = await store();
      s.dispatch(SubmitPhoneAction('11912345678'));

      await s.dispatchAndWait(VerifyCodeAction('123456'));

      expect(api.registrations.single, (
        phone: '+5511912345678',
        code: '123456',
      ));
      expect(api.uploads, hasLength(1));
      expect(s.state.account.status, AccountStatus.registered);
      expect(s.state.onboarding, const OnboardingState());
      expect(await AccountStore(secrets).device(), isNotNull);
    });

    const failures = <(AccountsError, OnboardingError)>[
      (AccountsError.invalidCode, OnboardingError.invalidCode),
      (AccountsError.invalidPhone, OnboardingError.invalidPhone),
      (AccountsError.rateLimited, OnboardingError.rateLimited),
      (AccountsError.network, OnboardingError.network),
      (AccountsError.unavailable, OnboardingError.unavailable),
      (AccountsError.invalidResponse, OnboardingError.failed),
    ];
    for (final (error, expected) in failures) {
      test('$error: mostra $expected e continua no código', () async {
        final s = await store();
        s.dispatch(SubmitPhoneAction('11912345678'));
        api.registerErrors.add(error);

        await s.dispatchAndWait(VerifyCodeAction('000000'));

        expect(s.state.account.status, AccountStatus.unregistered);
        expect(s.state.onboarding.phone, '+5511912345678');
        expect(s.state.onboarding.error, expected);
      });
    }

    test('erro do core: falha local', () async {
      core.keyErrors.add(CoreError.accountExists);
      final s = await store();
      s.dispatch(SubmitPhoneAction('11912345678'));

      await s.dispatchAndWait(VerifyCodeAction('123456'));

      expect(s.state.onboarding.error, OnboardingError.failed);
      expect(s.state.account.status, AccountStatus.unregistered);
    });

    test('core que não abriu: falha local, sem chamar o servidor', () async {
      final s = createStore(
        testDependencies(
          openCore: () async => throw StateError('chave errada'),
          accounts: api,
        ),
      );
      await s.dispatchAndWait(OpenCoreAction());
      s.dispatch(SubmitPhoneAction('11912345678'));

      await s.dispatchAndWait(VerifyCodeAction('123456'));

      expect(s.state.onboarding.error, OnboardingError.failed);
      expect(api.calls, isEmpty);
    });

    test(
      'nova tentativa depois de falha de rede reaproveita as chaves',
      () async {
        final s = await store();
        s.dispatch(SubmitPhoneAction('11912345678'));
        api.uploadErrors.add(AccountsError.network);

        await s.dispatchAndWait(VerifyCodeAction('123456'));
        await s.dispatchAndWait(VerifyCodeAction('123456'));

        expect(core.generatedKeys, 1);
        expect(s.state.account.status, AccountStatus.registered);
      },
    );
  });

  test('SaveProfileNameAction guarda o nome sem espaços nas pontas', () async {
    storeDevice();
    final s = await store();

    await s.dispatchAndWait(SaveProfileNameAction('  Ana Souza '));

    expect(s.state.account.profileName, 'Ana Souza');
    expect(secrets.values[AccountStore.profileNameName], 'Ana Souza');
  });

  test('SaveProfileNameAction ignora nome vazio', () async {
    storeDevice();
    final s = await store();

    await s.dispatchAndWait(SaveProfileNameAction('   '));

    expect(s.state.account.profileName, isNull);
  });

  group('SetPinAction', () {
    test('cria o PIN no servidor com as credenciais guardadas', () async {
      storeDevice();
      final s = await store();

      await s.dispatchAndWait(SetPinAction('2468'));

      expect(api.pins.single.pin, '2468');
      expect(api.pins.single.device.token, testDevice.token);
      expect(s.state.account.pin, PinStatus.set);
      expect((await AccountStore(secrets).load()).pin, PinStatus.set);
    });

    test('PIN curto não sai do aparelho', () async {
      storeDevice();
      final s = await store();

      await s.dispatchAndWait(SetPinAction('12'));

      expect(api.calls, isEmpty);
      expect(s.state.account.pin, PinStatus.notOffered);
    });

    test('servidor sem a rota: PIN continua a criar, com o erro', () async {
      storeDevice();
      api.pinErrors.add(AccountsError.unavailable);
      final s = await store();

      await s.dispatchAndWait(SetPinAction('2468'));

      expect(s.state.account.pin, PinStatus.notOffered);
      expect(s.state.onboarding.error, OnboardingError.unavailable);
      expect((await AccountStore(secrets).load()).pin, PinStatus.notOffered);
    });
  });

  group('DeferPinAction', () {
    test('adia e marca o lembrete para depois do intervalo', () async {
      storeDevice();
      final s = await store();

      await s.dispatchAndWait(DeferPinAction());

      final stored = await AccountStore(secrets).load();
      expect(s.state.account.pin, PinStatus.deferred);
      expect(s.state.account.pinReminderDue, isFalse);
      expect(stored.pin, PinStatus.deferred);
      expect(
        stored.pinRemindAt?.isAtSameMomentAs(now.add(pinReminderInterval)),
        isTrue,
      );
    });

    test('adiar de novo pelo lembrete esconde o lembrete', () async {
      storeDevice();
      await AccountStore(
        secrets,
      ).savePin(PinStatus.deferred, remindAt: now.subtract(Duration.zero));
      final s = await store();
      expect(s.state.account.pinReminderDue, isTrue);

      await s.dispatchAndWait(DeferPinAction());

      expect(s.state.account.pinReminderDue, isFalse);
    });

    test('PIN já criado não volta a adiado', () async {
      storeDevice();
      await AccountStore(secrets).savePin(PinStatus.set);
      final s = await store();

      await s.dispatchAndWait(DeferPinAction());

      expect(s.state.account.pin, PinStatus.set);
    });
  });
}
