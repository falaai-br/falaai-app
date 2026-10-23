import 'package:go_router/go_router.dart';

import 'ui/home_screen.dart';

/// Rotas do app.
GoRouter createRouter() => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
);
