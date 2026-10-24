import '../account/accounts_api.dart';
import '../account/phone_number.dart';
import '../account/pin.dart';
import '../account/registration.dart';
import 'actions.dart';
import 'app_state.dart';

/// Lê a conta guardada no aparelho, no início do app.
class LoadAccountAction extends AppAction {
  @override
  Future<AppState?> reduce() async {
    final stored = await deps.account.load();
    final remindAt = stored.pinRemindAt;
    return state.copyWith(
      account: AccountState(
        status: stored.device == null
            ? AccountStatus.unregistered
            : AccountStatus.registered,
        profileName: stored.profileName,
        pin: stored.pin,
        pinReminderDue:
            stored.pin == PinStatus.deferred &&
            (remindAt == null || !deps.now().isBefore(remindAt)),
      ),
    );
  }
}

/// Primeira tela: o número digitado vira E.164 e o onboarding passa ao código. O servidor
/// ainda não envia SMS (só aceita o código de dev); quando a rota existir, o pedido de envio
/// sai daqui.
class SubmitPhoneAction extends AppAction {
  SubmitPhoneAction(this.input);

  final String input;

  @override
  AppState reduce() {
    final phone = parseBrazilianMobile(input);
    return state.copyWith(
      onboarding: phone == null
          ? state.onboarding.copyWith(error: () => OnboardingError.invalidPhone)
          : OnboardingState(phone: phone),
    );
  }
}

/// Volta do código para o número.
class EditPhoneAction extends AppAction {
  @override
  AppState reduce() => state.copyWith(onboarding: const OnboardingState());
}

/// Segunda tela: registra o aparelho com o código do SMS.
class VerifyCodeAction extends _OnboardingAction {
  VerifyCodeAction(this.code);

  final String code;

  @override
  Future<AppState?> reduce() async {
    final phone = state.onboarding.phone;
    if (phone == null) return null;
    try {
      final core = deps.core;
      if (core == null) return failed(OnboardingError.failed);
      final registration = deps.registration ??= AccountRegistration(
        core,
        deps.accounts,
        deps.account,
      );
      await registration.register(phone: phone, code: code);
    } on AccountsError catch (e) {
      return failed(onboardingErrorOf(e));
    } catch (_) {
      // Core, armazenamento ou configuração. O detalhe não vai para log: pode carregar dado do
      // core ou do aparelho.
      return failed(OnboardingError.failed);
    }
    return state.copyWith(
      account: state.account.copyWith(status: AccountStatus.registered),
      onboarding: const OnboardingState(),
    );
  }
}

/// Terceira tela: o nome do perfil.
class SaveProfileNameAction extends AppAction {
  SaveProfileNameAction(this.name);

  final String name;

  @override
  Future<AppState?> reduce() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    await deps.account.saveProfileName(trimmed);
    return state.copyWith(
      account: state.account.copyWith(profileName: trimmed),
    );
  }
}

/// Cria o PIN de registro no servidor.
class SetPinAction extends _OnboardingAction {
  SetPinAction(this.pin);

  final String pin;

  @override
  Future<AppState?> reduce() async {
    if (!isValidPin(pin)) return null;
    try {
      final device = await deps.account.device();
      if (device == null) return failed(OnboardingError.failed);
      await deps.accounts.setRegistrationPin(device, pin);
      await deps.account.savePin(PinStatus.set);
    } on AccountsError catch (e) {
      return failed(onboardingErrorOf(e));
    } catch (_) {
      return failed(OnboardingError.failed);
    }
    return state.copyWith(
      account: state.account.copyWith(
        pin: PinStatus.set,
        pinReminderDue: false,
      ),
      onboarding: const OnboardingState(),
    );
  }
}

/// "Agora não" no PIN: o app lembra depois de [pinReminderInterval].
class DeferPinAction extends AppAction {
  @override
  Future<AppState?> reduce() async {
    if (state.account.pin == PinStatus.set) return null;
    await deps.account.savePin(
      PinStatus.deferred,
      remindAt: deps.now().add(pinReminderInterval),
    );
    return state.copyWith(
      account: state.account.copyWith(
        pin: PinStatus.deferred,
        pinReminderDue: false,
      ),
      onboarding: const OnboardingState(),
    );
  }
}

/// Passo do cadastro que fala com o servidor e pode falhar.
abstract class _OnboardingAction extends AppAction {
  /// O estado com [error] para a tela mostrar.
  AppState failed(OnboardingError error) =>
      state.copyWith(onboarding: state.onboarding.copyWith(error: () => error));
}

/// O que a tela diz para cada falha do `accounts`.
OnboardingError onboardingErrorOf(AccountsError error) => switch (error) {
  AccountsError.invalidPhone => OnboardingError.invalidPhone,
  AccountsError.invalidCode => OnboardingError.invalidCode,
  AccountsError.rateLimited => OnboardingError.rateLimited,
  AccountsError.network => OnboardingError.network,
  AccountsError.unavailable => OnboardingError.unavailable,
  AccountsError.unauthorized ||
  AccountsError.invalidResponse => OnboardingError.failed,
};
