# falaai-app

App do **FalaAí** para Android e iOS, em Flutter. Mensagens, grupos, mídia e chamadas com criptografia ponta a ponta. Toda a criptografia vive no [falaai-core](https://github.com/falaai-br/falaai-core), em Rust, sobre a libsignal.

## Desenvolvimento

Pré-requisitos: Flutter estável (Dart 3.9+), Android SDK, Xcode (para iOS) e Go (instala o osv-scanner e o gitleaks).

```sh
make tools   # dependências, ferramentas pinadas e git hooks (core.hooksPath=.githooks)
make help    # lista os alvos
```

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
