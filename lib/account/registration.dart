import 'package:falaai_core/falaai_core.dart';

import 'account_store.dart';
import 'accounts_api.dart';

/// Registro deste aparelho: o `accounts` confere o código do SMS e dá endereço e token, o core
/// gera as chaves da conta, o Dart publica a parte pública e só então guarda as credenciais. O
/// aparelho conta como registrado só depois do bundle publicado.
class AccountRegistration {
  AccountRegistration(this._core, this._api, this._account);

  final FalaaiCore _core;
  final AccountsApi _api;
  final AccountStore _account;

  /// O core gera as chaves uma vez só e não as devolve de novo. Se a publicação falhar (rede
  /// ruim), a próxima tentativa nesta sessão reaproveita estas.
  AccountKeys? _keys;

  /// Registra [phone] (E.164) com o [code] do SMS. Falhas do servidor saem como
  /// [AccountsError]; do core, como [CoreError].
  Future<DeviceCredentials> register({
    required String phone,
    required String code,
  }) async {
    final device = await _api.register(phone: phone, code: code);
    final keys = _keys ??= await _core.generateAccountKeys();
    await _core.setLocalAddress(address: device.address);
    await _api.uploadKeys(device, keys);
    await _account.saveDevice(device);
    _keys = null;
    return device;
  }
}
