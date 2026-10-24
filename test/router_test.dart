import 'package:falaai_app/router.dart';
import 'package:falaai_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const unregistered = AccountState(status: AccountStatus.unregistered);
  const named = AccountState(
    status: AccountStatus.registered,
    profileName: 'Ana',
  );

  AppState state(AccountState account, {String? phone}) => AppState(
    account: account,
    onboarding: OnboardingState(phone: phone),
  );

  const cases = <(String, AppState, String, String?)>[
    ('conta carregando: fica', AppState(), Routes.home, null),
    (
      'sem registro: número',
      AppState(account: unregistered),
      Routes.home,
      Routes.phone,
    ),
    (
      'sem registro, já na tela do número: fica',
      AppState(account: unregistered),
      Routes.phone,
      null,
    ),
    (
      'sem registro, tentando pular para o nome: número',
      AppState(account: unregistered),
      Routes.name,
      Routes.phone,
    ),
    (
      'registrado sem nome: nome',
      AppState(account: AccountState(status: AccountStatus.registered)),
      Routes.code,
      Routes.name,
    ),
    (
      'com nome, PIN não oferecido: PIN',
      AppState(account: named),
      Routes.name,
      Routes.pin,
    ),
    (
      'PIN adiado: lista de conversas',
      AppState(
        account: AccountState(
          status: AccountStatus.registered,
          profileName: 'Ana',
          pin: PinStatus.deferred,
        ),
      ),
      Routes.pin,
      null,
    ),
    (
      'PIN adiado, cadastro não volta',
      AppState(
        account: AccountState(
          status: AccountStatus.registered,
          profileName: 'Ana',
          pin: PinStatus.deferred,
        ),
      ),
      Routes.phone,
      Routes.home,
    ),
    (
      'PIN criado: a tela do PIN não volta',
      AppState(
        account: AccountState(
          status: AccountStatus.registered,
          profileName: 'Ana',
          pin: PinStatus.set,
        ),
      ),
      Routes.pin,
      Routes.home,
    ),
    (
      'tudo pronto, na lista: fica',
      AppState(
        account: AccountState(
          status: AccountStatus.registered,
          profileName: 'Ana',
          pin: PinStatus.set,
        ),
      ),
      Routes.home,
      null,
    ),
  ];
  for (final (name, appState, location, expected) in cases) {
    test(name, () => expect(redirectFor(appState, location), expected));
  }

  test('número à espera do código: código', () {
    expect(
      redirectFor(state(unregistered, phone: '+5511912345678'), Routes.phone),
      Routes.code,
    );
  });
}
