# Use bash for richer shell features (pipefail, brace expansion…)
SHELL := /bin/bash

# Optional .env file with project defaults ------------------------------------
ENV_FILE ?= .env

ifneq ("$(wildcard $(ENV_FILE))","")
include $(ENV_FILE)
ENV_VARS := $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' $(ENV_FILE))
export $(ENV_VARS)
endif

# Tooling discovery ------------------------------------------------------------
DOCKER := $(shell command -v docker 2>/dev/null)
ifeq ($(DOCKER),)
$(error "docker não encontrado. Instale o Docker e tente novamente.")
endif

COMPOSE := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

# Global configuration ---------------------------------------------------------
PROJECT ?= $(if $(COMPOSE_PROJECT_NAME),$(COMPOSE_PROJECT_NAME),ro-dou)
WAIT_WEB_TIMEOUT ?= 60

DEV_PROFILE ?= dev
ifneq ($(strip $(DEV_PROFILE)),)
DEV_PROFILE_ARG := --profile $(DEV_PROFILE)
endif

ifdef WSL_DISTRO_NAME
POSTGRES_DATA_VOLUME ?= rodou_pgdata
else
POSTGRES_DATA_VOLUME ?= ./mnt/pgdata
endif
export POSTGRES_DATA_VOLUME

COMPOSE_CMD := $(COMPOSE) $(DEV_PROFILE_ARG) -p $(PROJECT)
AIRFLOW_EXEC := $(COMPOSE_CMD) exec -T airflow-webserver
SCHED_EXEC   := $(COMPOSE_CMD) exec -T airflow-scheduler

AIRFLOW_AUTH := $(AIRFLOW_USER):$(AIRFLOW_PASSWORD)

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo "Targets: run build-images setup-containers wait-web tests smoke-test redeploy down"

# Bootstrap --------------------------------------------------------------------
.PHONY: run
run: build-images create-logs-dir setup-containers wait-web \
	create-example-variable create-path-tmp-variable \
	create-inlabs-db create-inlabs-db-connection \
	create-inlabs-portal-connection activate-inlabs-load-dag

.PHONY: build-images
build-images:
	$(COMPOSE_CMD) build airflow-webserver airflow-scheduler

.PHONY: create-logs-dir
create-logs-dir:
	mkdir -p ./mnt/airflow-logs
	chmod a+rwx ./mnt/airflow-logs

.PHONY: setup-containers
setup-containers:
	$(COMPOSE_CMD) up -d

.PHONY: create-example-variable
create-example-variable:
	@echo "Creating 'termos_exemplo_variavel' Airflow variable"
	@$(AIRFLOW_EXEC) sh -eu -c "\
		if curl -fsLI 'http://localhost:8080/api/v1/variables/termos_exemplo_variavel' --user '$(AIRFLOW_AUTH)' >/dev/null; then \
			exit 0; \
		fi; \
		curl -sS -X POST 'http://localhost:8080/api/v1/variables' \
			-H 'accept: application/json' \
			-H 'Content-Type: application/json' \
			--user '$(AIRFLOW_AUTH)' \
			-d '{\"key\":\"termos_exemplo_variavel\",\"value\":\"LGPD\\nlei geral de proteção de dados\\nacesso à informação\"}' >/dev/null"

.PHONY: create-path-tmp-variable
create-path-tmp-variable:
	@echo "Creating 'path_tmp' Airflow variable"
	@$(AIRFLOW_EXEC) sh -eu -c "\
		if curl -fsLI 'http://localhost:8080/api/v1/variables/path_tmp' --user '$(AIRFLOW_AUTH)' >/dev/null; then \
			exit 0; \
		fi; \
		curl -sS -X POST 'http://localhost:8080/api/v1/variables' \
			-H 'accept: application/json' \
			-H 'Content-Type: application/json' \
			--user '$(AIRFLOW_AUTH)' \
			-d '{\"key\":\"path_tmp\",\"value\":\"$(AIRFLOW_TMP_DIR)\"}' >/dev/null"

.PHONY: create-inlabs-db
create-inlabs-db:
	@echo "Creating 'inlabs' database schema"
	@$(COMPOSE_CMD) exec -T postgres env PGPASSWORD="$(POSTGRES_PASSWORD)" \
		psql --username="$(POSTGRES_USER)" --dbname="$(POSTGRES_DB)" --file=/sql/init-db.sql >/dev/null

.PHONY: create-inlabs-db-connection
create-inlabs-db-connection:
	@echo "Ensuring 'inlabs_db' Airflow connection exists"
	@$(AIRFLOW_EXEC) sh -eu -c "\
		if curl -fsLI 'http://localhost:8080/api/v1/connections/inlabs_db' --user '$(AIRFLOW_AUTH)' >/dev/null; then \
			exit 0; \
		fi; \
		curl -sS -X POST 'http://localhost:8080/api/v1/connections' \
			-H 'accept: application/json' \
			-H 'Content-Type: application/json' \
			--user '$(AIRFLOW_AUTH)' \
			-d '{\"connection_id\":\"inlabs_db\",\"conn_type\":\"postgres\",\"schema\":\"inlabs\",\"host\":\"$(POSTGRES_HOST)\",\"login\":\"$(POSTGRES_USER)\",\"password\":\"$(POSTGRES_PASSWORD)\",\"port\":$(POSTGRES_PORT)}' >/dev/null"

.PHONY: create-inlabs-portal-connection
create-inlabs-portal-connection:
	@echo "Recreating 'inlabs_portal' Airflow connection"
	@$(AIRFLOW_EXEC) airflow connections delete inlabs_portal >/dev/null 2>&1 || true
	@$(AIRFLOW_EXEC) airflow connections add inlabs_portal \
		--conn-type http \
		--conn-host "$(INLABS_PORTAL_HOST)" \
		--conn-login "$(INLABS_PORTAL_LOGIN)" \
		--conn-password "$(INLABS_PORTAL_PASSWORD)" \
		--conn-description "Credencial para acesso no Portal do INLabs"

.PHONY: activate-inlabs-load-dag
activate-inlabs-load-dag:
	@echo "Activating 'ro-dou_inlabs_load_pg' DAG"
	@$(AIRFLOW_EXEC) sh -eu -c "\
		curl -sS -X PATCH 'http://localhost:8080/api/v1/dags/ro-dou_inlabs_load_pg' \
			-H 'accept: application/json' \
			-H 'Content-Type: application/json' \
			--user '$(AIRFLOW_AUTH)' \
			-d '{\"is_paused\":false}' >/dev/null"

# Lifecycle helpers ------------------------------------------------------------
.PHONY: redeploy
redeploy: build-images
	$(COMPOSE_CMD) up -d --no-deps airflow-webserver airflow-scheduler
	$(MAKE) smoke-test

.PHONY: tests
tests:
	$(AIRFLOW_EXEC) sh -c "cd /opt/airflow/tests && \
		PYTHONPATH=/opt/airflow/dags:/opt/airflow/dags/dags python -m pytest -vvv --color=yes"

.PHONY: smoke-test
smoke-test:
	@$(AIRFLOW_EXEC) bash -lc "python -c 'import requests; print(\"webserver https://www.in.gov.br ->\", requests.get(\"https://www.in.gov.br\", timeout=10).status_code)'"
	@$(SCHED_EXEC) bash -lc "python -c 'import requests; print(\"scheduler https://www.in.gov.br ->\", requests.get(\"https://www.in.gov.br\", timeout=10).status_code)'"

.PHONY: wait-web
wait-web:
	@echo "Waiting for airflow-webserver (health=healthy) ..."
	@for i in $$(seq 1 $(WAIT_WEB_TIMEOUT)); do \
		state=$$(docker inspect --format='{{.State.Health.Status}}' airflow-webserver 2>/dev/null || echo "starting"); \
		if [ "$$state" = "healthy" ]; then echo "airflow-webserver is healthy"; exit 0; fi; \
		sleep 3; \
	done; \
	echo "Timeout waiting for airflow-webserver health=healthy"; exit 1

.PHONY: dev-up dev-down
dev-up:
	$(COMPOSE_CMD) up -d

dev-down:
	$(COMPOSE_CMD) down

.PHONY: smtp4dev-up smtp4dev-down smtp4dev-stop smtp4dev-rm
smtp4dev-up:
	$(COMPOSE_CMD) up -d smtp4dev

smtp4dev-down: smtp4dev-stop smtp4dev-rm

smtp4dev-stop:
	$(COMPOSE_CMD) stop smtp4dev || true

smtp4dev-rm:
	$(COMPOSE_CMD) rm -f smtp4dev || true

.PHONY: down
down:
	$(COMPOSE_CMD) down
