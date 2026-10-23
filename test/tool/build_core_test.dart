import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_core.dart';

void main() {
  group('abisFor', () {
    for (final (targetPlatform, abis) in [
      (null, ['arm64-v8a', 'armeabi-v7a', 'x86_64']),
      ('', ['arm64-v8a', 'armeabi-v7a', 'x86_64']),
      ('android-arm64', ['arm64-v8a']),
      (
        'android-arm,android-arm64,android-x64',
        ['armeabi-v7a', 'arm64-v8a', 'x86_64'],
      ),
    ]) {
      test('${targetPlatform ?? 'sem target-platform'} -> $abis', () {
        expect(abisFor(targetPlatform), abis);
      });
    }

    test('plataforma sem build do core é erro', () {
      expect(() => abisFor('android-x86'), throwsArgumentError);
    });
  });

  group('crateDirFrom', () {
    String config(List<Map<String, String>> packages) =>
        jsonEncode({'configVersion': 2, 'packages': packages});

    final configUri = Uri.file('/app/.dart_tool/package_config.json');

    test('pacote do pub cache: a crate é o pai de dart/', () {
      final dir = crateDirFrom(
        config([
          {'name': 'flutter', 'rootUri': 'file:///sdk/packages/flutter'},
          {
            'name': 'falaai_core',
            'rootUri': 'file:///cache/git/falaai-core-3e3503a/dart',
          },
        ]),
        configUri,
      );

      expect(dir.uri, Uri.directory('/cache/git/falaai-core-3e3503a/'));
    });

    test('rootUri relativo resolve a partir do package_config', () {
      final dir = crateDirFrom(
        config([
          {'name': 'falaai_core', 'rootUri': '../../falaai-core/dart/'},
        ]),
        configUri,
      );

      expect(dir.uri, Uri.directory('/falaai-core/'));
    });

    test('sem falaai_core no package_config é erro', () {
      expect(() => crateDirFrom(config([]), configUri), throwsStateError);
    });
  });
}
