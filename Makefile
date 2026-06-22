.PHONY: local-up local-down local-logs local-reset

local-up:
	docker compose up --build

local-down:
	docker compose down

local-reset:
	docker compose down -v

local-logs:
	docker compose logs -f
