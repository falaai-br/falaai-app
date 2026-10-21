# falaai-app — pipeline de qualidade.
include mk/hooks.mk

OSV_SCANNER_VERSION ?= v2.2.3
HAS_APP := $(wildcard pubspec.yaml)
GITLEAKS ?= $(shell command -v gitleaks || echo $(HOME)/go/bin/gitleaks)
OSV ?= $(shell command -v osv-scanner || echo $(HOME)/go/bin/osv-scanner)

.PHONY: tools fmt lint test test-integration test-device security build check check-fast
tools: hooks ## Dependências, ferramentas pinadas e hooks
	flutter --version
	@if [ -n "$(HAS_APP)" ]; then flutter pub get; fi
	go install github.com/google/osv-scanner/v2/cmd/osv-scanner@$(OSV_SCANNER_VERSION)

fmt: ## Formata
	dart format .

lint: ## dart format check e flutter analyze estrito
	dart format --output=none --set-exit-if-changed .
	@if [ -n "$(HAS_APP)" ]; then flutter analyze --fatal-infos --fatal-warnings; else echo "projeto Flutter ainda não criado"; fi

test: ## Testes unitários e de widget com cobertura
	@if [ -n "$(HAS_APP)" ]; then flutter test --coverage; else echo "projeto Flutter ainda não criado"; fi

test-integration: ## Testes de integração que não exigem aparelho (redux + core mockado)
	@if [ -d test_integration ]; then flutter test test_integration; else echo "sem test_integration/ ainda"; fi

test-device: ## integration_test em aparelho/emulador conectado. Fora do hook
	flutter test integration_test

security: ## osv-scanner no pubspec.lock e gitleaks
	@if [ -f pubspec.lock ]; then $(OSV) scan source --lockfile=pubspec.lock; fi
	$(GITLEAKS) git --no-banner --redact .

build: ## Build Android de verificação
	@if [ -f pubspec.yaml ]; then flutter build apk --debug --target-platform android-arm64; else echo "projeto Flutter ainda não criado"; fi

check-fast: ## pre-commit
	dart format --output=none --set-exit-if-changed .
	@if [ -n "$(HAS_APP)" ]; then flutter analyze --no-pub --fatal-warnings; fi
	$(GITLEAKS) git --no-banner --redact --staged .

check: lint test test-integration security build ## pre-push e gate do Refinery
