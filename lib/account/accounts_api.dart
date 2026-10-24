import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:falaai_core/falaai_core.dart';

/// Dígitos do código de verificação que chega por SMS.
const verificationCodeLength = 6;

/// Dispositivo registrado no `accounts`: o endereço que o servidor deu e o token que o
/// autentica. O token fica no `SecretStore`; nunca vai para o estado da UI nem para log.
class DeviceCredentials {
  const DeviceCredentials({
    required this.aci,
    required this.deviceId,
    required this.token,
  });

  /// Lê o JSON de [toJson] (o mesmo formato da resposta do registro).
  factory DeviceCredentials.fromJson(Object? json) {
    if (json case {
      'aci': final String aci,
      'device_id': final int deviceId,
      'token': final String token,
    } when aci.isNotEmpty && deviceId > 0 && token.isNotEmpty) {
      return DeviceCredentials(aci: aci, deviceId: deviceId, token: token);
    }
    throw AccountsError.invalidResponse;
  }

  final String aci;
  final int deviceId;
  final String token;

  DeviceAddress get address => DeviceAddress(aci: aci, deviceId: deviceId);

  /// Cabeçalho `Authorization` das rotas autenticadas: `Basic base64(aci.device:token)`.
  String get authorization =>
      'Basic ${base64Encode(utf8.encode('$aci.$deviceId:$token'))}';

  Map<String, Object> toJson() => {
    'aci': aci,
    'device_id': deviceId,
    'token': token,
  };
}

/// Falha de uma chamada ao `accounts`. As variantes não carregam telefone, código, PIN nem token.
enum AccountsError implements Exception {
  /// O servidor recusou o telefone.
  invalidPhone,

  /// Código de verificação errado ou vencido.
  invalidCode,

  /// O servidor não atende o pedido agora: registro desligado ou rota ainda não publicada.
  unavailable,

  /// Limite de tentativas; tentar mais tarde.
  rateLimited,

  /// O servidor recusou o token do dispositivo.
  unauthorized,

  /// Falha de rede, de TLS ou tempo esgotado; tentar de novo.
  network,

  /// O servidor respondeu fora do contrato.
  invalidResponse,
}

/// Rotas do `accounts` e do diretório de chaves que o app chama no registro. O registro e o
/// upload do bundle são do Dart (o core só gera as chaves e devolve a parte pública).
abstract interface class AccountsApi {
  /// `POST /v1/accounts`: registra este aparelho como dispositivo primário de [phone] (E.164)
  /// com o [code] do SMS. Um telefone que já tinha conta mantém o ACI e ganha token novo.
  Future<DeviceCredentials> register({
    required String phone,
    required String code,
  });

  /// `PUT /v1/keys`: publica a parte pública das chaves da conta.
  Future<void> uploadKeys(DeviceCredentials device, AccountKeys keys);

  /// `PUT /v1/accounts/me/registration-lock`: cria ou troca o PIN de registro. O servidor
  /// guarda só o verificador. Contrato proposto ao fls-163; sem a rota, [AccountsError.unavailable].
  Future<void> setRegistrationPin(DeviceCredentials device, String pin);
}

/// [AccountsApi] sobre o HTTP do `dart:io`. Sem certificados raiz próprios, como o core: confia
/// nas raízes do sistema.
class HttpAccountsApi implements AccountsApi {
  /// [baseUrl] é o `FALAAI_ACCOUNTS_URL` da build: `https://…`, ou `http://` só no loopback.
  /// [platform] é `android` ou `ios`.
  HttpAccountsApi({
    required String baseUrl,
    required this.platform,
    HttpClient? client,
  }) : _base = checkBaseUrl(baseUrl),
       _client = (client ?? HttpClient())..connectionTimeout = timeout;

  /// Limite de cada etapa da requisição (conectar, enviar, receber).
  static const timeout = Duration(seconds: 15);

  /// Maior corpo de resposta aceito; as respostas do contrato têm algumas centenas de bytes.
  static const maxResponseBytes = 16 * 1024;

  /// Confere a base do `accounts`: sem TLS só no loopback, e sem caminho.
  static Uri checkBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final loopback =
        uri != null &&
        (uri.host == 'localhost' ||
            (InternetAddress.tryParse(uri.host)?.isLoopback ?? false));
    final valid =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        (uri.scheme == 'https' || (uri.scheme == 'http' && loopback));
    if (!valid) {
      throw const FormatException(
        'FALAAI_ACCOUNTS_URL tem de ser https:// (http:// só no loopback), sem caminho',
      );
    }
    return uri.replace(path: '');
  }

  final Uri _base;
  final HttpClient _client;
  final String platform;

  @override
  Future<DeviceCredentials> register({
    required String phone,
    required String code,
  }) async {
    final response = await _send('POST', '/v1/accounts', {
      'phone': phone,
      'code': code,
      'platform': platform,
    });
    return switch (response.status) {
      200 || 201 => DeviceCredentials.fromJson(response.json()),
      400 when response.hasError('telefone_invalido') =>
        throw AccountsError.invalidPhone,
      403 => throw AccountsError.invalidCode,
      _ => throw response.error(),
    };
  }

  @override
  Future<void> uploadKeys(DeviceCredentials device, AccountKeys keys) async {
    final response = await _send('PUT', '/v1/keys', {
      'identityKey': base64Encode(keys.identityKey),
      'registrationId': keys.registrationId,
      'signedPreKey': _signed(keys.signedPreKey),
      'pqLastResortPreKey': _signed(keys.kyberLastResortPreKey),
      'preKeys': [
        for (final key in keys.preKeys)
          {'keyId': key.id, 'publicKey': base64Encode(key.publicKey)},
      ],
      'pqPreKeys': [for (final key in keys.kyberPreKeys) _signed(key)],
    }, device: device);
    if (response.status != 200) throw response.error();
  }

  @override
  Future<void> setRegistrationPin(DeviceCredentials device, String pin) async {
    final response = await _send('PUT', '/v1/accounts/me/registration-lock', {
      'pin': pin,
    }, device: device);
    if (response.status == 204 || response.status == 200) return;
    // Sem a rota no servidor (fls-163), o PIN ainda não pode ser criado.
    if (response.status == 404) throw AccountsError.unavailable;
    throw response.error();
  }

  static Map<String, Object> _signed(SignedPreKey key) => {
    'keyId': key.id,
    'publicKey': base64Encode(key.publicKey),
    'signature': base64Encode(key.signature),
  };

  /// Envia [body] em JSON e lê a resposta inteira. Falhas de rede viram [AccountsError.network];
  /// o detalhe não sai daqui, porque pode carregar o endereço do servidor ou do aparelho.
  Future<_Response> _send(
    String method,
    String path,
    Map<String, Object> body, {
    DeviceCredentials? device,
  }) async {
    try {
      final request = await _client
          .openUrl(method, _base.replace(path: path))
          .timeout(timeout);
      request
        ..followRedirects = false
        ..headers.contentType = ContentType.json;
      if (device != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          device.authorization,
        );
      }
      final encoded = utf8.encode(jsonEncode(body));
      request
        ..contentLength = encoded.length
        ..add(encoded);
      final response = await request.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxResponseBytes) {
          throw AccountsError.invalidResponse;
        }
      }
      return _Response(response.statusCode, bytes);
    } on IOException {
      throw AccountsError.network;
    } on TimeoutException {
      throw AccountsError.network;
    }
  }
}

class _Response {
  _Response(this.status, this._body);

  final int status;
  final List<int> _body;

  /// O corpo em JSON; corpo que não é JSON é resposta fora do contrato.
  Object? json() {
    try {
      return jsonDecode(utf8.decode(_body));
    } on FormatException {
      throw AccountsError.invalidResponse;
    }
  }

  /// Se o corpo é o erro `{"erro": code}` do `accounts`.
  bool hasError(String code) {
    try {
      if (json() case {'erro': final String erro}) return erro == code;
    } on AccountsError {
      // Corpo que não é JSON não é o erro procurado.
    }
    return false;
  }

  /// O erro dos status comuns a todas as rotas.
  AccountsError error() => switch (status) {
    401 => AccountsError.unauthorized,
    429 => AccountsError.rateLimited,
    503 => AccountsError.unavailable,
    _ => AccountsError.invalidResponse,
  };
}
