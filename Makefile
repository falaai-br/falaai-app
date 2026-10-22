# falaai-app — pipeline de qualidade.
include mk/hooks.mk

OSV_SCANNER_VERSION ?= v2.2.3
GITLEAKS_VERSION    ?= 8.28.0
OSV ?= osv-scanner
# Aparelho para make test-device (id de 'flutter devices'). Vazio: o flutter escolhe.
DEVICE ?=

.PHONY: tools fmt lint test test-integration test-device security build check check-fast
tools: hooks ## Dependências, ferramentas pinadas e hooks
	flutter --version
	flutter precache --android --ios
	flutter pub get
	@command -v go >/dev/null || { echo "instale Go para o osv-scanner e o gitleaks: https://go.dev/dl"; exit 1; }
	go install github.com/google/osv-scanner/v2/cmd/osv-scanner@$(OSV_SCANNER_VERSION)
	go install github.com/zricethezav/gitleaks/v8@v$(GITLEAKS_VERSION)

fmt: ## Formata
	dart format .

lint: ## dart format check e flutter analyze estrito
	dart format --output=none --set-exit-if-changed .
	flutter analyze --fatal-infos --fatal-warnings

test: ## Testes unitários e de widget com cobertura
	flutter test --coverage

test-integration: ## Testes de integração que não exigem aparelho (hooks, redux + core mockado)
	flutter test test_integration

test-device: ## integration_test em aparelho/emulador conectado (DEVICE=<id>). Fora do hook
	flutter test integration_test $(if $(DEVICE),-d $(DEVICE))

security: ## osv-scanner no pubspec.lock e gitleaks
	$(OSV) scan source --lockfile=pubspec.lock
	$(GITLEAKS) git --no-banner --redact .

build: ## Build Android de verificação
	flutter build apk --debug --target-platform android-arm64

check-fast: ## pre-commit
	dart format --output=none --set-exit-if-changed .
	flutter analyze --no-pub --fatal-warnings
	$(GITLEAKS) git --no-banner --redact --staged .

check: lint test test-integration security build ## pre-push e gate do Refinery
