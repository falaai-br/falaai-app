import 'package:falaai_core/falaai_core.dart';

import '../../l10n/app_localizations.dart';

/// Como chamar a conta [aci] na UI enquanto não há perfis (o nome chega com a profile key):
/// "Contato" e o começo do id.
String contactName(AppLocalizations l10n, String aci) =>
    l10n.chatContact(aci.length > 8 ? aci.substring(0, 8) : aci);

/// Letra do avatar de [peer].
String contactInitial(DeviceAddress peer) =>
    peer.aci.isEmpty ? '?' : peer.aci.substring(0, 1).toUpperCase();

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// [input] como ACI em minúsculas, ou `null` se não é um UUID.
String? parseAci(String input) {
  final trimmed = input.trim().toLowerCase();
  return _uuid.hasMatch(trimmed) ? trimmed : null;
}
