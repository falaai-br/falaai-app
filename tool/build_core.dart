// Compila o falaai-core (Rust) para Android com o cargo-ndk e deixa as .so em <out>/jniLibs.
//
// Chamado pelo Gradle antes de cada build do app (android/app/build.gradle.kts). Native
// Assets (ADR-0003) não está disponível no Flutter estável 3.35, então o core entra como
// jniLibs. O código Rust é o do pacote falaai_core resolvido pelo pub (dependência git pinada
// por commit no pubspec.yaml): a crate fica na raiz do repositório, o pacote Dart em dart/.
//
// Uso: dart tool/build_core.dart --out <dir> --ndk <dir> --min-sdk <n> [--target-platform <p>]
//      dart tool/build_core.dart --crate-dir   (só imprime o diretório da crate; make tools)
import 'dart:convert';
import 'dart:io';

/// ABIs Android do core, pelo nome que o Flutter passa em `-Ptarget-platform`.
const coreAbis = {
  'android-arm64': 'arm64-v8a',
  'android-arm': 'armeabi-v7a',
  'android-x64': 'x86_64',
};

/// ABIs para o `target-platform` do Flutter (lista separada por vírgula). Vazio: todas.
List<String> abisFor(String? targetPlatform) {
  final platforms = (targetPlatform ?? '')
      .split(',')
      .map((platform) => platform.trim())
      .where((platform) => platform.isNotEmpty)
      .toList();
  if (platforms.isEmpty) return coreAbis.values.toList();
  return [
    for (final platform in platforms)
      coreAbis[platform] ??
          (throw ArgumentError.value(
            platform,
            'target-platform',
            'plataforma sem build do falaai-core',
          )),
  ];
}

/// Diretório da crate do falaai-core, a partir do `.dart_tool/package_config.json` em
/// [configUri]: o pacote Dart fica em `dart/` dentro do repositório do core.
Directory crateDirFrom(String packageConfig, Uri configUri) {
  final config = jsonDecode(packageConfig) as Map<String, Object?>;
  final packages = (config['packages'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final core = packages.firstWhere(
    (package) => package['name'] == 'falaai_core',
    orElse: () => throw StateError(
      'falaai_core fora do package_config.json: rode flutter pub get',
    ),
  );
  final root = configUri.resolve(_asDirectory(core['rootUri'] as String));
  return Directory.fromUri(root.resolve('..'));
}

/// Ambiente do `cargo ndk`. O protoc pinado vai em `PROTOC`, que o prost-build lê, e na frente
/// do [path] herdado, porque o protobuf-codegen do zkgroup só procura no `PATH`.
Map<String, String> cargoEnvironment({
  required String ndk,
  required String out,
  required String protocDir,
  required String? path,
}) => {
  'ANDROID_NDK_HOME': ndk,
  'CARGO_TARGET_DIR': '$out/target',
  'PROTOC': '$protocDir/bin/protoc',
  'PATH': [
    '$protocDir/bin',
    if (path != null && path.isNotEmpty) path,
  ].join(':'),
};

String _asDirectory(String uri) => uri.endsWith('/') ? uri : '$uri/';

Future<void> main(List<String> args) async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final crate = crateDirFrom(await configFile.readAsString(), configFile.uri);
  if (args case ['--crate-dir']) {
    stdout.writeln(crate.path);
    return;
  }
  final options = _parse(args);
  final out = Directory(options.require('out')).absolute;
  if (!File.fromUri(crate.uri.resolve('Cargo.toml')).existsSync()) {
    stderr.writeln('Cargo.toml do falaai-core não encontrado em ${crate.path}');
    exit(1);
  }
  final abis = abisFor(options['target-platform']);
  final protocDir = '${out.path}/protoc';
  final jniLibs = Directory('${out.path}/jniLibs');

  // O protoc pinado e o checksum são os do Makefile do core; só o destino muda, para não
  // escrever no cache do pub.
  await _run('make', [
    '-C',
    crate.path,
    'protoc',
    'PROTOC_DIR=$protocDir',
  ], crate.path);

  // Uma .so de outra versão do core quebraria a checagem de hash da ponte no init.
  if (jniLibs.existsSync()) jniLibs.deleteSync(recursive: true);
  await _run(
    'cargo',
    [
      'ndk',
      for (final abi in abis) ...['-t', abi],
      '-P',
      options.require('min-sdk'),
      '-o',
      jniLibs.path,
      'build',
      '--release',
      '--locked',
    ],
    crate.path,
    environment: cargoEnvironment(
      ndk: options.require('ndk'),
      out: out.path,
      protocDir: protocDir,
      path: Platform.environment['PATH'],
    ),
  );
}

Future<void> _run(
  String executable,
  List<String> arguments,
  String workingDirectory, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('$executable ${arguments.join(' ')} falhou ($code)');
    exit(code);
  }
}

typedef _Options = Map<String, String>;

extension on _Options {
  String require(String name) =>
      this[name] ?? (throw ArgumentError('faltou --$name'));
}

_Options _parse(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (!args[i].startsWith('--')) throw ArgumentError('argumento: ${args[i]}');
    options[args[i].substring(2)] = args[i + 1];
  }
  return options;
}
