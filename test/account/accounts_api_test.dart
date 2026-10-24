import 'dart:convert';
import 'dart:io';

import 'package:falaai_app/account/accounts_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Pedido recebido pelo servidor de teste.
typedef Received = ({
  String method,
  String path,
  String? authorization,
  Object? body,
});

void main() {
  late HttpServer server;
  late List<Received> received;

  /// Resposta que o servidor de teste dá ao próximo pedido.
  late ({int status, Object? body}) reply;

  setUp(() async {
    received = [];
    reply = (status: 200, body: null);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final text = await utf8.decodeStream(request);
      received.add((
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        body: text.isEmpty ? null : jsonDecode(text),
      ));
      request.response.statusCode = reply.status;
      final body = reply.body;
      if (body is String) {
        request.response.write(body);
      } else if (body != null) {
        request.response.write(jsonEncode(body));
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  HttpAccountsApi api() => HttpAccountsApi(
    baseUrl: 'http://127.0.0.1:${server.port}',
    platform: 'android',
  );

  final registered = {
    'aci': testDevice.aci,
    'device_id': testDevice.deviceId,
    'token': testDevice.token,
  };

  group('register', () {
    test('envia telefone, código e plataforma e lê as credenciais', () async {
      reply = (status: 201, body: registered);

      final device = await api().register(
        phone: '+5511912345678',
        code: '123456',
      );

      expect(received.single.method, 'POST');
      expect(received.single.path, '/v1/accounts');
      expect(received.single.authorization, isNull);
      expect(received.single.body, {
        'phone': '+5511912345678',
        'code': '123456',
        'platform': 'android',
      });
      expect(device.aci, testDevice.aci);
      expect(device.deviceId, 1);
      expect(device.token, testDevice.token);
    });

    test('novo registro de conta existente (200) também vale', () async {
      reply = (status: 200, body: registered);

      final device = await api().register(phone: '+5511912345678', code: '1');

      expect(device.aci, testDevice.aci);
    });

    const errors = <(int, Object?, AccountsError)>[
      (403, {'erro': 'codigo_invalido'}, AccountsError.invalidCode),
      (400, {'erro': 'telefone_invalido'}, AccountsError.invalidPhone),
      (400, {'erro': 'corpo_invalido'}, AccountsError.invalidResponse),
      (429, null, AccountsError.rateLimited),
      (503, {'erro': 'registro_indisponivel'}, AccountsError.unavailable),
      (500, {'erro': 'interno'}, AccountsError.invalidResponse),
      (201, 'não é json', AccountsError.invalidResponse),
      (201, {'aci': 'x'}, AccountsError.invalidResponse),
    ];
    for (final (status, body, error) in errors) {
      test('$status $body -> $error', () async {
        reply = (status: status, body: body);

        await expectLater(
          api().register(phone: '+5511912345678', code: '000000'),
          throwsA(error),
        );
      });
    }

    test('resposta grande demais é recusada', () async {
      reply = (status: 201, body: 'x' * (HttpAccountsApi.maxResponseBytes + 1));

      await expectLater(
        api().register(phone: '+5511912345678', code: '1'),
        throwsA(AccountsError.invalidResponse),
      );
    });

    test('servidor fora do ar é falha de rede', () async {
      final port = server.port;
      await server.close(force: true);

      await expectLater(
        HttpAccountsApi(
          baseUrl: 'http://127.0.0.1:$port',
          platform: 'ios',
        ).register(phone: '+5511912345678', code: '1'),
        throwsA(AccountsError.network),
      );
    });
  });

  group('uploadKeys', () {
    test(
      'publica a parte pública das chaves com o token do dispositivo',
      () async {
        await api().uploadKeys(testDevice, testAccountKeys);

        final request = received.single;
        expect(request.method, 'PUT');
        expect(request.path, '/v1/keys');
        expect(
          request.authorization,
          'Basic ${base64Encode(utf8.encode('${testDevice.aci}.1:${testDevice.token}'))}',
        );
        expect(request.body, {
          'identityKey': base64Encode([5, 1, 1]),
          'registrationId': 4242,
          'signedPreKey': {
            'keyId': 1,
            'publicKey': base64Encode([5, 2]),
            'signature': base64Encode([9, 2]),
          },
          'pqLastResortPreKey': {
            'keyId': 2,
            'publicKey': base64Encode([8, 3]),
            'signature': base64Encode([9, 3]),
          },
          'preKeys': [
            {
              'keyId': 10,
              'publicKey': base64Encode([5, 10]),
            },
            {
              'keyId': 11,
              'publicKey': base64Encode([5, 11]),
            },
          ],
          'pqPreKeys': [
            {
              'keyId': 20,
              'publicKey': base64Encode([8, 20]),
              'signature': base64Encode([9, 20]),
            },
          ],
        });
      },
    );

    const errors = <(int, AccountsError)>[
      (401, AccountsError.unauthorized),
      (429, AccountsError.rateLimited),
      (400, AccountsError.invalidResponse),
    ];
    for (final (status, error) in errors) {
      test('$status -> $error', () async {
        reply = (status: status, body: null);

        await expectLater(
          api().uploadKeys(testDevice, testAccountKeys),
          throwsA(error),
        );
      });
    }
  });

  group('setRegistrationPin', () {
    test('envia o PIN com o token do dispositivo', () async {
      reply = (status: 204, body: null);

      await api().setRegistrationPin(testDevice, '2468');

      expect(received.single.method, 'PUT');
      expect(received.single.path, '/v1/accounts/me/registration-lock');
      expect(received.single.authorization, startsWith('Basic '));
      expect(received.single.body, {'pin': '2468'});
    });

    const errors = <(int, AccountsError)>[
      // Rota ainda não publicada (fls-163).
      (404, AccountsError.unavailable),
      (401, AccountsError.unauthorized),
      (429, AccountsError.rateLimited),
    ];
    for (final (status, error) in errors) {
      test('$status -> $error', () async {
        reply = (status: status, body: null);

        await expectLater(
          api().setRegistrationPin(testDevice, '2468'),
          throwsA(error),
        );
      });
    }
  });

  group('checkBaseUrl', () {
    const valid = [
      'https://accounts.falaai.com.br',
      'https://accounts.falaai.com.br/',
      'http://127.0.0.1:8080',
      'http://localhost:8080',
      'http://[::1]:8080',
    ];
    for (final url in valid) {
      test('aceita $url', () {
        expect(HttpAccountsApi.checkBaseUrl(url).path, isEmpty);
      });
    }

    const invalid = [
      '',
      'http://10.0.2.2:8080',
      'http://accounts.falaai.com.br',
      'https://accounts.falaai.com.br/v1',
      'https://accounts.falaai.com.br?x=1',
      'ftp://127.0.0.1',
    ];
    for (final url in invalid) {
      test('recusa "$url"', () {
        expect(() => HttpAccountsApi.checkBaseUrl(url), throwsFormatException);
      });
    }
  });
}
