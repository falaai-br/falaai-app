// Garante que os git hooks versionados em .githooks bloqueiam o que devem.
// Cada caso roda os hooks reais num repositório temporário cujo Makefile falha ou passa conforme o caso.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _Case {
  const _Case(
    this.name, {
    required this.message,
    this.checkFastExit = 0,
    this.checkExit = 0,
    this.push = false,
    this.wantFail,
  });

  final String name;
  final String message;
  final int checkFastExit;
  final int checkExit;
  final bool push;
  final String? wantFail;
}

const _cases = [
  _Case(
    'commit com Conventional Commits é aceito',
    message: 'feat(keys): consumir one-time prekey no fetch',
  ),
  _Case(
    'commit fora do padrão é recusado',
    message: 'update stuff',
    wantFail: 'FALAAI-HOOK: FAIL gate=commit-msg',
  ),
  _Case(
    'commit com tipo desconhecido é recusado',
    message: 'feature: algo novo',
    wantFail: 'FALAAI-HOOK: FAIL gate=commit-msg',
  ),
  _Case(
    'pre-commit bloqueia quando check-fast falha',
    message: 'fix: corrigir algo',
    checkFastExit: 1,
    wantFail: 'FALAAI-HOOK: FAIL gate=check-fast hook=pre-commit',
  ),
  _Case(
    'pre-push libera quando check passa',
    message: 'chore: algo',
    push: true,
  ),
  _Case(
    'pre-push bloqueia quando check falha',
    message: 'chore: algo',
    checkExit: 1,
    push: true,
    wantFail: 'FALAAI-HOOK: FAIL gate=check hook=pre-push',
  ),
];

void main() {
  final hooksDir = Directory('.githooks').absolute.path;

  for (final tt in _cases) {
    test(tt.name, () {
      final dir = Directory.systemTemp.createTempSync('falaai-githooks-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = '${dir.path}/repo';
      final remote = '${dir.path}/remote.git';

      _git(dir.path, ['init', '-q', '--bare', remote]);
      _git(dir.path, ['init', '-q', '-b', 'main', repo]);
      _git(repo, ['config', 'core.hooksPath', hooksDir]);
      _git(repo, ['config', 'user.name', 'FalaAí Teste']);
      _git(repo, ['config', 'user.email', 'teste@falaai.invalid']);

      File('$repo/Makefile').writeAsStringSync(
        'check-fast:\n\t@exit ${tt.checkFastExit}\n'
        'check:\n\t@exit ${tt.checkExit}\n',
      );
      _git(repo, ['add', 'Makefile']);

      var result = _run(repo, ['commit', '-q', '-m', tt.message]);
      if (tt.push) {
        expect(result.exitCode, 0, reason: result.output);
        result = _run(repo, ['push', '-q', remote, 'HEAD:refs/heads/main']);
      }

      final wantFail = tt.wantFail;
      if (wantFail == null) {
        expect(result.exitCode, 0, reason: result.output);
      } else {
        expect(result.exitCode, isNot(0), reason: result.output);
        expect(result.output, contains(wantFail));
      }
    });
  }
}

void _git(String dir, List<String> args) {
  final result = _run(dir, args);
  expect(result.exitCode, 0, reason: result.output);
}

({int exitCode, String output}) _run(String dir, List<String> args) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: dir,
    environment: _isolatedEnv(),
    includeParentEnvironment: false,
  );
  return (
    exitCode: result.exitCode,
    output: '${result.stdout}${result.stderr}',
  );
}

// Remove o que vaza do processo pai: este teste também roda dentro do pre-push,
// onde o git exporta GIT_DIR e afins, e dentro do make, que exporta MAKEFLAGS.
Map<String, String> _isolatedEnv() {
  final env = Map<String, String>.of(Platform.environment)
    ..removeWhere(
      (key, _) =>
          key.startsWith('GIT_') ||
          key.startsWith('MAKE') ||
          key == 'MFLAGS' ||
          key == 'FALAAI_SKIP_HOOKS',
    );
  return env
    ..['GIT_CONFIG_GLOBAL'] = '/dev/null'
    ..['GIT_CONFIG_NOSYSTEM'] = '1';
}
