.PHONY: local-up local-down local-logs local-reset prod-config

# Dev stack: production-shaped base + dev override (source mounts, dev servers).
DEV_COMPOSE = docker compose -f docker-compose.yml -f docker-compose.dev.yml

local-up:
	$(DEV_COMPOSE) up --build

local-down:
	$(DEV_COMPOSE) down

local-reset:
	$(DEV_COMPOSE) down -v

local-logs:
	$(DEV_COMPOSE) logs -f

# Validate the production-shaped base compose (requires a populated .env).
prod-config:
	docker compose -f docker-compose.yml config -q
