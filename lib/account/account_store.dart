import 'dart:convert';

import '../core/database_key.dart';
import 'accounts_api.dart';
import 'pin.dart';

/// O que o aparelho sabe da própria conta, como ficou guardado.
class StoredAccount {
  const StoredAccount({
    this.device,
    this.profileName,
    this.pin = PinStatus.notOffered,
    this.pinRemindAt,
  });

  /// Credenciais do registro; `null` se o aparelho não terminou de se registrar.
  final DeviceCredentials? device;

  /// Nome do perfil. Fica só no aparelho até a profile key levá-lo aos contatos (flc-qfd).
  final String? profileName;

  final PinStatus pin;

  /// Quando lembrar do PIN adiado.
  final DateTime? pinRemindAt;
}

/// Conta do aparelho no [SecretStore]: credenciais (o token autentica o dispositivo), nome do
/// perfil e estado do PIN. O PIN em si nunca é guardado.
class AccountStore {
  AccountStore(this._store);

  static const deviceName = 'falaai.account.device';
  static const profileNameName = 'falaai.account.profile_name';
  static const pinName = 'falaai.account.pin';

  final SecretStore _store;

  /// Lê o que foi guardado. Credenciais malformadas contam como aparelho sem registro: o
  /// onboarding registra de novo e o servidor troca o token.
  Future<StoredAccount> load() async {
    final device = await this.device();
    final profileName = await _store.read(profileNameName);
    final (pin, remindAt) = _parsePin(await _store.read(pinName));
    return StoredAccount(
      device: device,
      profileName: profileName,
      pin: pin,
      pinRemindAt: remindAt,
    );
  }

  /// As credenciais guardadas, se houver.
  Future<DeviceCredentials?> device() async {
    final stored = await _store.read(deviceName);
    if (stored == null) return null;
    try {
      return DeviceCredentials.fromJson(jsonDecode(stored));
    } on FormatException {
      return null;
    } on AccountsError {
      return null;
    }
  }

  Future<void> saveDevice(DeviceCredentials device) =>
      _store.write(deviceName, jsonEncode(device.toJson()));

  Future<void> saveProfileName(String name) =>
      _store.write(profileNameName, name);

  Future<void> savePin(PinStatus pin, {DateTime? remindAt}) => _store.write(
    pinName,
    jsonEncode({
      'status': pin.name,
      if (remindAt != null) 'remind_at': remindAt.millisecondsSinceEpoch,
    }),
  );

  static (PinStatus, DateTime?) _parsePin(String? stored) {
    if (stored == null) return (PinStatus.notOffered, null);
    try {
      final json = jsonDecode(stored);
      if (json case {'status': final String status}) {
        final pin = PinStatus.values.asNameMap()[status];
        final remindAt = json['remind_at'];
        if (pin != null) {
          return (
            pin,
            remindAt is int
                ? DateTime.fromMillisecondsSinceEpoch(remindAt)
                : null,
          );
        }
      }
    } on FormatException {
      // Valor malformado: oferece o PIN de novo.
    }
    return (PinStatus.notOffered, null);
  }
}
