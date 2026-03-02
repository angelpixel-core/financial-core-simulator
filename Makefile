.DEFAULT_GOAL := help

.PHONY: help setup setup-root setup-admin db-up db-down db-logs test test-root test-admin test-perf smoke-manual quality lint-admin docs-check status

help: ## Mostrar tareas disponibles
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

setup: setup-root setup-admin ## Instalar dependencias de root y admin

setup-root: ## Instalar dependencias del core Ruby
	bundle install

setup-admin: ## Instalar dependencias de apps/admin
	BUNDLE_GEMFILE=apps/admin/Gemfile bundle install

db-up: ## Levantar PostgreSQL local con docker compose
	docker compose up -d postgres

db-down: ## Bajar PostgreSQL local
	docker compose down

db-logs: ## Ver logs de PostgreSQL local
	docker compose logs -f postgres

test: test-root test-admin ## Ejecutar bateria base (core + admin)

test-root: ## Ejecutar tests del core
	bundle exec rspec spec

test-admin: ## Ejecutar tests de apps/admin
	BUNDLE_GEMFILE=apps/admin/Gemfile bundle exec rspec -Iapps/admin/spec apps/admin/spec

test-perf: ## Ejecutar tests de performance (tag :perf)
	bundle exec rspec --tag perf

smoke-manual: ## Ejecutar smoke manual asistido (requiere server en :3000)
	bash scripts/smoke_manual.sh

lint-admin: ## Ejecutar RuboCop en apps/admin
	BUNDLE_GEMFILE=apps/admin/Gemfile bundle exec rubocop apps/admin

docs-check: ## Verificar que no queden referencias a docs/discussion
	@! rg -n "docs/discussion/" docs

quality: test test-perf docs-check ## Ejecutar chequeos de calidad estandar

status: ## Mostrar resumen de cambios git
	@git status --short
