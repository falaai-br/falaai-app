import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'state/app_state.dart';
import 'ui/chat/chat_screen.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding/code_screen.dart';
import 'ui/onboarding/name_screen.dart';
import 'ui/onboarding/phone_screen.dart';
import 'ui/onboarding/pin_screen.dart';

/// Caminhos das telas.
abstract final class Routes {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const phone = '$onboarding/phone';
  static const code = '$onboarding/code';
  static const name = '$onboarding/name';
  static const pin = '$onboarding/pin';
  static const chat = '/chat';

  /// Tela de chat com a conta [aci]; também o deep link `falaai://chat/<aci>`.
  static String chatWith(String aci) => '$chat/$aci';
}

/// Rotas do app. O passo do onboarding sai do estado ([redirectFor]): cada action que avança o
/// cadastro muda o estado, e o router leva à tela certa.
GoRouter createRouter(Store<AppState> store, Listenable refresh) => GoRouter(
  refreshListenable: refresh,
  redirect: (_, route) => redirectFor(store.state, route.matchedLocation),
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(path: Routes.phone, builder: (_, _) => const PhoneScreen()),
    GoRoute(path: Routes.code, builder: (_, _) => const CodeScreen()),
    GoRoute(path: Routes.name, builder: (_, _) => const NameScreen()),
    GoRoute(path: Routes.pin, builder: (_, _) => const PinScreen()),
    GoRoute(
      path: '${Routes.chat}/:aci',
      builder: (_, state) =>
          ChatScreen(conversationId: state.pathParameters['aci']!),
    ),
  ],
);

/// Para onde ir a partir de [location], ou `null` para ficar. Enquanto a conta carrega, fica
/// onde está (a tela inicial mostra o progresso). O cadastro segue número, código, nome e PIN;
/// depois dele, as telas de cadastro não voltam, a não ser a do PIN enquanto ele não existir
/// (o lembrete leva até ela).
String? redirectFor(AppState state, String location) {
  final account = state.account;
  final step = switch (account) {
    AccountState(status: AccountStatus.loading) => null,
    AccountState(status: AccountStatus.unregistered) =>
      state.onboarding.phone == null ? Routes.phone : Routes.code,
    AccountState(profileName: null) => Routes.name,
    AccountState(pin: PinStatus.notOffered) => Routes.pin,
    _ => Routes.home,
  };
  if (step == null || step == location) return null;
  if (step == Routes.home) {
    final pinAllowed = location == Routes.pin && account.pin != PinStatus.set;
    if (pinAllowed || !location.startsWith(Routes.onboarding)) return null;
  }
  return step;
}

/// Avisa o router quando muda o que decide a rota: a conta ou o número à espera do código.
class OnboardingRefresh extends ChangeNotifier {
  OnboardingRefresh(Store<AppState> store) {
    _subscription = store.onChange
        .map((state) => (state.account, state.onboarding.phone))
        .distinct()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
