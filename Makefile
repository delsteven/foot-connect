include infra/.env infra/.env.local

MAKEFLAGS += --no-print-directory
TAG    := $(shell git describe --tags --abbrev=0 2> /dev/null || echo 'latest')
IMG    := ${NAME}:${TAG}
LATEST := ${NAME}:latest

COMPOSE_FILE ?= infra/docker/compose.yml
ifneq ("$(wildcard infra/docker/compose.override.yml)","")
    COMPOSE_FILE := infra/docker/compose.yml:infra/docker/compose.override.yml
endif
DOCKER_COMPOSE := COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker compose
SYMFONY := $(DOCKER_COMPOSE) exec -T frankenphp php -d memory_limit=2G bin/console
YARN := $(DOCKER_COMPOSE) run --rm node yarn
COMPOSER := $(DOCKER_COMPOSE) exec -T frankenphp composer

export COMPOSE_FILE COMPOSE_PROJECT_NAME MAX_EXECUTION_TIME TIMEZONE SERVER_NAME POSTGRES_DB POSTGRES_PASSWORD POSTGRES_USER

### Docker

up: ## Démarre les containers
	$(MAKE) run cmd='rm -rf var/cache/prod'
	$(DOCKER_COMPOSE) up  -d --no-recreate frankenphp

stop: ## Stop les containers
	$(DOCKER_COMPOSE) stop

down: ## Supprime les containers
	$(DOCKER_COMPOSE) down

build: ## Build les différentes images
	$(eval service :=)
	$(eval target :=)
	$(target) $(DOCKER_COMPOSE) build --no-cache $(service)

exec: ## Connexion au container php
	$(eval c := frankenphp)
	$(eval cmd := sh)
	$(DOCKER_COMPOSE) exec  $(c) $(cmd)

run: ## Démarre un container
	$(eval c := frankenphp)
	$(eval cmd := sh)
	$(DOCKER_COMPOSE) run --rm --no-deps $(c) $(cmd)

### Environnement de développement

init:
	$(MAKE) composer.json infra/docker/compose.override.yml
	$(MAKE) build up assets-build fixtures fix-permissions

fixtures: vendor ## Charge les fixtures en base de données
	$(SYMFONY) doctrine:database:drop --if-exists --force
	$(SYMFONY) doctrine:database:create
	$(SYMFONY) doctrine:migrations:migrate --no-interaction --allow-no-migration
	$(SYMFONY) doctrine:fixture:load --no-interaction || true

grumphp: ## Lance grumphp
	$(DOCKER_COMPOSE) run --rm --no-deps frankenphp ./vendor/bin/grumphp run

phpunit: ## Lance phpunit
	$(DOCKER_COMPOSE) exec -T frankenphp ./bin/phpunit

fix-permissions: ## Corrige les problèmes de permissions
	$(DOCKER_COMPOSE) exec -T frankenphp chown -R www-data:www-data var public

vendor: ## Install les dépendances composer
	$(COMPOSER) install

migration: ## Créer un fichier de migration
	$(SYMFONY) make:migration

migrate: ## Lance les migrations
	$(SYMFONY) doctrine:migration:migrate -n

### Fronts (css/js)
node: ## Lance le container node
	$(MAKE) run c=node

yarn-install: ## Lance yarn install
	$(YARN) cache clean
	$(YARN) install

assets-build: yarn-install ## Build les assets en mode prod (mode dev : 'make assets-build env=dev')
	$(eval env := prod)
	$(YARN) encore $(env)

assets-watch: yarn-install ## Lance le mode dev avec l'option --watch
	$(YARN) encore dev --watch

composer.json:
	$(DOCKER_COMPOSE) build frankenphp
	$(DOCKER_COMPOSE) run --rm --no-deps frankenphp sh /usr/local/bin/install-symfony.sh

infra/docker/compose.override.yml:
	cp infra/docker/compose.override.yml.dist infra/docker/compose.override.yml
