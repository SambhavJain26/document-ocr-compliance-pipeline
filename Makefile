# Vendor COI Chasing - operational commands
.DEFAULT_GOAL := help
SHELL := /bin/bash

# Keep `make help` usable before local secrets exist.
-include .env
export

COMPOSE := docker compose --project-name vendor-coi-chasing --env-file .env -f infra/docker-compose.yml
PSQL    := $(COMPOSE) exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

.PHONY: help doctor up down logs restart \
        infra-verify \
        credentials-import credentials-verify \
        db-apply db-seed db-verify db-reset db-shell \
        fixtures fixtures-clean \
        test test-all test-extract test-fixtures test-forbidden \
        demo-reset backup

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

doctor:  ## Verify local prerequisites (Stage 0 gate)
	@bash db/scripts/doctor.sh

up:  ## Start the local PostgreSQL and n8n services
	$(COMPOSE) up -d

down:  ## Stop this project's services
	$(COMPOSE) down

logs:  ## Tail this project's service logs
	$(COMPOSE) logs -f --tail=100

restart:  ## Restart this project's n8n service only
	$(COMPOSE) restart n8n

infra-verify:  ## Verify the local Stage 1 infrastructure gate
	@bash infra/verify.sh

credentials-import:  ## Import the PostgreSQL n8n credential from .env
	@bash n8n/scripts/import-credentials.sh

credentials-verify:  ## Verify PostgreSQL plus n8n-native OpenAI and Gmail credentials
	@bash n8n/scripts/verify-credentials.sh

db-apply:  ## Apply all migrations in order
	@bash db/scripts/apply.sh

db-seed:  ## Load idempotent demo seed data
	@bash db/scripts/seed.sh

db-verify:  ## Verify schema and seed state (Stage 2 gate)
	@bash db/scripts/verify.sh

db-shell:  ## Open a psql shell inside this project's container
	$(COMPOSE) exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

demo-reset:  ## Reset to the demo opening state (Stage 9)
	@bash db/scripts/reset-demo.sh

fixtures:  ## Regenerate all test fixtures
	cd fixtures && python generate.py --spec spec/fixtures.json --out out/

fixtures-clean:  ## Remove generated fixture output
	rm -rf fixtures/out/*

test: test-all

test-all: test-extract test-fixtures test-forbidden  ## Run every automated check

test-extract:  ## Unit-test extraction and validation logic
	node --test test/unit/test_extract.js

test-fixtures:  ## Run all 20 fixtures through the live pipeline
	python test/run_fixtures.py

test-forbidden:  ## Scan rendered output for prohibited claims
	python test/forbidden_words.py

backup:  ## Dump both PostgreSQL databases into ./backups
	@mkdir -p backups
	$(COMPOSE) exec -T postgres pg_dumpall -U $(POSTGRES_USER) \
	  | gzip > backups/coi-$$(date +%Y%m%d-%H%M%S).sql.gz
	@echo "Backup written to backups/"
