# falaai-app

App do **FalaAí** para Android e iOS, em Flutter. Mensagens, grupos, mídia e chamadas com criptografia ponta a ponta. Toda a criptografia vive no [falaai-core](https://github.com/falaai-br/falaai-core), em Rust, sobre a libsignal.

## Desenvolvimento

Pré-requisitos: Flutter estável (Dart 3.9+), Android SDK com o NDK, [rustup](https://rustup.rs), Xcode (para iOS) e Go (instala o osv-scanner e o gitleaks).

```sh
make tools   # dependências, targets Rust do Android, cargo-ndk, ferramentas pinadas e git hooks
make help    # lista os alvos
```

### Estrutura

| Caminho | O que tem |
|---|---|
| `lib/state/` | Async Redux: `AppState`, actions e as dependências injetadas na store |
| `lib/core/` | Abertura do falaai-core, a chave do banco e o certificado de remetente (Keychain/Keystore) |
| `lib/config/` | Configuração do ambiente embutida na build |
| `config/` | Um JSON por ambiente, lido por `--dart-define-from-file` |
| `lib/router.dart` | Rotas (`go_router`) |
| `lib/l10n/` | Textos em ARB (pt-BR); o código gerado é versionado |
| `lib/ui/` | Telas |
| `tool/build_core.dart` | Build Android do falaai-core, chamado pelo Gradle |

### falaai-core

O núcleo em Rust vem do pacote `falaai_core`, dependência git pinada por commit no `pubspec.yaml`: os bindings Dart ficam em `dart/` e a crate na raiz do mesmo repositório. Para atualizar o core, troque o `ref` e rode `flutter pub get`.

No Android, todo build do Gradle (`flutter run`, `make build`) roda `tool/build_core.dart` antes: o cargo-ndk compila a crate em release para as ABIs do build e as `.so` entram como `jniLibs`. O primeiro build leva uns 10 minutos (libsignal e SQLCipher); depois o cargo reaproveita `build/falaai_core/target`. Native Assets (ADR-0003) ainda não está disponível no Flutter estável 3.35.

A chave do SQLCipher (256 bits) é gerada no primeiro uso e guardada no Keychain (`first_unlock_this_device`) ou no Keystore. O backup do Android fica desligado: a chave não sai do aparelho e um banco restaurado em outro não abriria.

### Ambientes e sealed sender

Cada ambiente tem um `config/<ambiente>.json`, embutido na build com `--dart-define-from-file`. O Makefile usa `FALAAI_ENV` (padrão `dev`); com `flutter run`, passe o arquivo à mão:

```sh
flutter run --dart-define-from-file=config/dev.json
make build FALAAI_ENV=dev
```

`FALAAI_TRUST_ROOT` é a chave pública raiz do servidor (33 bytes em base64), publicada pelo `accounts` (ADR-0010). O app nunca a baixa em tempo de execução: trocar de trust root é trocar de build. Sem ela, ou malformada, o core não abre.

O certificado de remetente (24h) fica no Keychain/Keystore e volta ao core a cada abertura; quando o core diz que falta ou venceu, o app pede outro ao `accounts` e cifra de novo (`lib/core/sender_certificate.dart`).

Não há CI remoto (ADR-0009): o pipeline roda nos git hooks e no Refinery do Gas Town.

| Alvo | O que faz |
|---|---|
| `make check-fast` | `pre-commit`: formatação, `flutter analyze` e segredos no que está staged |
| `make check` | `pre-push` e gate do Refinery: `lint`, `test`, `test-integration`, `security`, `build` |
| `make test` | Testes unitários e de widget em `test/`, com cobertura |
| `make test-integration` | Testes em `test_integration/` que rodam sem aparelho (hooks do git, redux, core mockado) |
| `make test-device` | Testes em `integration_test/` num aparelho ou emulador conectado |

### Testes em aparelho

`make test-device` fica fora dos hooks porque precisa de um aparelho. É critério de saída das beads de UI: rodar em um iPhone e em um Android físicos antes de `gt done`.

```sh
flutter devices                    # lista os aparelhos conectados
make test-device DEVICE=<id>       # roda integration_test/ no aparelho escolhido
```

Sem `DEVICE`, o Flutter usa o único aparelho conectado ou pergunta qual usar.

## Licença

AGPL-3.0. Ver [LICENSE](LICENSE).
