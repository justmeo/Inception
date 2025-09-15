SHELL := /bin/bash
COMPOSE := docker compose -f srcs/docker-compose.yml --env-file srcs/.env

# Load LOGIN from .env when present
ifneq (,$(wildcard srcs/.env))
include srcs/.env
export
endif

# Data paths required by the subject
DATA_DIR := /home/$(LOGIN)/data
DB_DATA := $(DATA_DIR)/mariadb
WP_DATA := $(DATA_DIR)/wordpress

# Default target
.PHONY: all
all: up

.PHONY: up
up: ensure-dirs
	$(COMPOSE) up -d --build

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: build
build:
	$(COMPOSE) build --no-cache

.PHONY: restart
restart:
	$(COMPOSE) down
	$(COMPOSE) up -d --build

.PHONY: logs
logs:
	$(COMPOSE) logs -f --tail=200

.PHONY: ps
ps:
	$(COMPOSE) ps

.PHONY: clean
clean:
	$(COMPOSE) down -v --remove-orphans

.PHONY: fclean
fclean: clean
	rm -rf $(DB_DATA) $(WP_DATA)

.PHONY: re
re: fclean up

.PHONY: ensure-dirs
ensure-dirs:
	@if [[ -z "$(LOGIN)" ]]; then echo "LOGIN is not set in srcs/.env"; exit 1; fi
	@sudo mkdir -p $(DB_DATA) $(WP_DATA)
	@sudo chown -R $$USER:$$USER $(DATA_DIR)
	@echo "Data directories ready at $(DATA_DIR)"