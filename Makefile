PANTOS_VALIDATOR_NODE_VERSION := $(shell command -v poetry >/dev/null 2>&1 && poetry version -s || echo "0.0.0")
PANTOS_VALIDATOR_NODE_SSH_HOST ?= bdev-validatornode01
PYTHON_FILES_WITHOUT_TESTS := pantos/validatornode linux/scripts/start-web.py
PYTHON_FILES := $(PYTHON_FILES_WITHOUT_TESTS) tests
STACK_BASE_NAME=stack-validator-node
INSTANCE_COUNT ?= 1
DEV_MODE ?= false

.PHONY: check-version
check-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is not set"; \
		exit 1; \
	fi
	@VERSION_FROM_POETRY=$$(poetry version -s) ; \
	if test "$$VERSION_FROM_POETRY" != "$(VERSION)"; then \
		echo "Version mismatch: expected $(VERSION), got $$VERSION_FROM_POETRY" ; \
		exit 1 ; \
	else \
		echo "Version check passed" ; \
	fi

.PHONY: dist
dist: tar wheel debian

.PHONY: code
code: check format lint sort bandit test

.PHONY: check
check:
	poetry run mypy $(PYTHON_FILES_WITHOUT_TESTS)
	poetry run mypy --explicit-package-bases tests

.PHONY: format
format:
	poetry run yapf --in-place --recursive $(PYTHON_FILES)

.PHONY: format-check
format-check:
	poetry run yapf --diff --recursive $(PYTHON_FILES)

.PHONY: lint
lint:
	poetry run flake8 $(PYTHON_FILES)

.PHONY: sort
sort:
	poetry run isort --force-single-line-imports $(PYTHON_FILES)

.PHONY: sort-check
sort-check:
	poetry run isort --force-single-line-imports $(PYTHON_FILES) --check-only

.PHONY: bandit
bandit:
	poetry run bandit -r $(PYTHON_FILES) --quiet --configfile=.bandit

.PHONY: bandit-check
bandit-check:
	poetry run bandit -r $(PYTHON_FILES) --configfile=.bandit

.PHONY: test
test:
	poetry run python3 -m pytest tests --ignore tests/database/postgres

.PHONY: test-postgres
test-postgres:
	poetry run python3 -m pytest tests/database/postgres

.PHONY: coverage
coverage:
	poetry run python3 -m pytest --cov-report term-missing --cov=pantos tests --ignore tests/database/postgres

.PHONY: coverage-postgres
coverage-postgres:
	poetry run python3 -m pytest --cov-report term-missing --cov=pantos tests/database/postgres

.PHONY: coverage-all
coverage-all:
	poetry run python3 -m pytest --cov-report term-missing --cov=pantos tests

.PHONY: tar
tar: dist/pantos_validator_node-$(PANTOS_VERSION).tar.gz

dist/pantos_validator_node-$(PANTOS_VERSION).tar.gz: pantos alembic.ini validator-node-config.yml validator-node-config.env pantos-validator-node.sh pantos-validator-node-worker.sh
	cp validator-node-config.yml pantos/validator-node-config.yml
	cp validator-node-config.env pantos/validator-node-config.env
	cp alembic.ini pantos/alembic.ini
	cp pantos-validator-node.sh pantos/pantos-validator-node.sh
	cp pantos-validator-node-worker.sh pantos/pantos-validator-node-worker.sh
	chmod 755 pantos/pantos-validator-node.sh
	chmod 755 pantos/pantos-validator-node-worker.sh
	poetry build -f sdist
	rm pantos/validator-node-config.yml
	rm pantos/validator-node-config.env
	rm pantos/alembic.ini
	rm pantos/pantos-validator-node.sh
	rm pantos/pantos-validator-node-worker.sh

check-poetry-plugin:
	@if poetry self show plugins | grep -q poetry-plugin-freeze; then \
		echo "poetry-plugin-freeze is already added."; \
	else \
		echo "poetry-plugin-freeze is not added. Adding now..."; \
		poetry self add poetry-plugin-freeze; \
	fi

freeze-wheel: check-poetry-plugin
	poetry freeze-wheel

.PHONY: wheel
wheel: dist/pantos_validator_node-$(PANTOS_VERSION)-py3-none-any.whl freeze-wheel

dist/pantos_validator_node-$(PANTOS_VERSION)-py3-none-any.whl: pantos alembic.ini validator-node-config.yml validator-node-config.env
	cp validator-node-config.yml pantos/validator-node-config.yml
	cp validator-node-config.env pantos/validator-node-config.env
	cp alembic.ini pantos/alembic.ini
	poetry build -f wheel
	rm pantos/alembic.ini
	rm pantos/validator-node-config.yml
	rm pantos/validator-node-config.env

.PHONY: debian-build-deps
debian-build-deps:
	mk-build-deps --install --tool "apt-get --no-install-recommends -y" debian/control --remove

.PHONY: debian-full
debian-full:
	mkdir -p dist
	sed 's/VERSION_PLACEHOLDER/$(PANTOS_VALIDATOR_NODE_VERSION)/' configurator/DEBIAN/control.template > configurator/DEBIAN/control
	dpkg-deb --build configurator dist/pantos-validator-node-full_$(PANTOS_VALIDATOR_NODE_VERSION)_all.deb
	rm configurator/DEBIAN/control

.PHONY: debian
debian:
	$(eval debian_package := pantos-validator-node_$(PANTOS_VALIDATOR_NODE_VERSION)_*.deb)
	@if ! conda --version; then \
		echo "Conda not found. Please install conda."; \
		exit 1; \
	fi; \
	dpkg-buildpackage -uc -us -g
	mkdir -p dist
	ARCHITECTURE=$$(dpkg --print-architecture); \
	mv ../$(debian_package) dist/pantos-validator-node_$(PANTOS_SERVICE_NODE_VERSION)_$${ARCHITECTURE}.deb

.PHONY: debian-all
debian-all: debian debian-full

.PHONY: docker-debian-build
docker-debian-build:
	docker buildx build -t pantos-validator-node-build -f Dockerfile --target dev . --load $(ARGS);
	CONTAINER_ID=$$(docker create pantos-validator-node-build); \
    docker cp $${CONTAINER_ID}:/app/dist/ .; \
    docker rm $${CONTAINER_ID}

.PHONY: remote-install
remote-install: debian-all
	$(eval deb_file := pantos-validator-node*_$(PANTOS_VALIDATOR_NODE_VERSION)_*.deb)
	scp dist/$(deb_file) $(PANTOS_VALIDATOR_NODE_SSH_HOST):
ifdef DEV_PANTOS_COMMON
	scp -r $(DEV_PANTOS_COMMON) $(PANTOS_VALIDATOR_NODE_SSH_HOST):
	ssh -t $(PANTOS_VALIDATOR_NODE_SSH_HOST) "\
		sudo systemctl stop pantos-validator-node-celery;\
		sudo systemctl stop pantos-validator-node-server;\
		sudo apt install -y ./$(deb_file);\
		sudo rm -rf /opt/pantos/pantos-validator-node/lib/python3.*/site-packages/pantos/common/;\
		sudo cp -r common/ /opt/pantos/pantos-validator-node/lib/python3.*/site-packages/pantos/;\
		sudo systemctl start pantos-validator-node-server;\
		sudo systemctl start pantos-validator-node-celery;\
		rm -rf common;\
		rm $(deb_file)"
else
	ssh -t $(PANTOS_VALIDATOR_NODE_SSH_HOST) "\
		sudo systemctl stop pantos-validator-node-celery;\
		sudo systemctl stop pantos-validator-node-server;\
		sudo apt install -y ./$(deb_file);\
		sudo systemctl start pantos-validator-node-server;\
		sudo systemctl start pantos-validator-node-celery;\
		rm $(deb_file)"
endif

.PHONY: local-common
local-common:
ifndef DEV_PANTOS_COMMON
	$(error Please define DEV_PANTOS_COMMON variable)
endif
	$(eval CURRENT_COMMON := $(shell echo .venv/lib/python3.*/site-packages/pantos/common))
	@if [ -d "$(CURRENT_COMMON)" ]; then \
		rm -rf "$(CURRENT_COMMON)"; \
		ln -s "$(DEV_PANTOS_COMMON)" "$(CURRENT_COMMON)"; \
	else \
		echo "Directory $(CURRENT_COMMON) does not exist"; \
	fi

.PHONY: install
install: dist/pantos_validator_node-$(PANTOS_VERSION)-py3-none-any.whl
	poetry run python3 -m pip install dist/pantos_validator_node-$(PANTOS_VERSION)-py3-none-any.whl

.PHONY: uninstall
uninstall:
	poetry run python3 -m pip uninstall -y pantos-validator-node

.PHONY: clean
clean:
	rm -r -f build/
	rm -r -f dist/
	rm -r -f pantos_validator_node.egg-info/

check-swarm-init:
	@if [ "$$(docker info --format '{{.Swarm.LocalNodeState}}')" != "active" ]; then \
        echo "Docker is not part of a swarm. Initializing..."; \
        docker swarm init; \
    else \
        echo "Docker is already part of a swarm."; \
    fi

docker-build:
	@if [ "$$NO_BUILD" != "true" ]; then \
		docker buildx bake -f docker-compose.yml --load $(ARGS); \
	fi

docker: check-swarm-init docker-build
	@for i in $$(seq 1 $(INSTANCE_COUNT)); do \
		( \
        STACK_NAME="${STACK_BASE_NAME}-${STACK_IDENTIFIER}-$$i"; \
		if [ $$i -eq 1 ]; then \
			export APP_MODE="primary"; \
		else \
			export APP_MODE="secondary"; \
		fi; \
		export INSTANCE=$$i; \
		echo "Deploying stack $$STACK_NAME"; \
		if [ "$(DEV_MODE)" = "true" ]; then \
			echo "Running in development mode"; \
			EXTRA_COMPOSE="$(EXTRA_COMPOSE) --watch"; \
		fi ; \
        docker compose -f docker-compose.yml -f docker-compose.override.yml -p $$STACK_NAME $$EXTRA_COMPOSE up -d --wait $(ARGS); \
		) & \
    done; \
	wait
    #docker stack deploy -c docker-compose.yml -c docker-compose.override.yml $$STACK_NAME --with-registry-auth --detach=false $(ARGS) & \

.PHONY: docker-remove
docker-remove:
	@STACK_NAME="${STACK_BASE_NAME}"; \
    if [ -n "$(STACK_IDENTIFIER)" ]; then \
        STACK_NAME="$$STACK_NAME-$(STACK_IDENTIFIER)"; \
        echo "Removing the stack with identifier $(STACK_IDENTIFIER)"; \
    else \
        echo "** Removing all stacks **"; \
    fi; \
    for stack in $$(docker stack ls --format "{{.Name}}" | awk "/^$$STACK_NAME/ {print}"); do \
        ( \
        echo "Removing stack $$stack"; \
        docker stack rm $$stack --detach=false; \
        echo "Removing volumes for stack $$stack"; \
        docker volume ls --format "{{.Name}}" | awk '/^$$stack/ {print}' | xargs -r docker volume rm \
        ) & \
    done;  \
    for compose_stack in $$(docker compose ls --filter "name=$$STACK_NAME" --format json | jq -r '.[].Name' | awk "/^$$STACK_NAME/ {print}"); do \
        ( \
        echo "Removing Docker Compose stack $$compose_stack"; \
        docker compose -p $$compose_stack down -v \
        ) & \
    done; \
	wait

.PHONY: docker-logs
docker-logs:
	@for stack in $$(docker stack ls --format "{{.Name}}" | awk '/^${STACK_BASE_NAME}-${STACK_IDENTIFIER}/ {print}'); do \
        echo "Showing logs for stack $$stack"; \
        for service in $$(docker stack services --format "{{.Name}}" $$stack); do \
            echo "Logs for service $$service in stack $$stack"; \
            docker service logs --no-task-ids $$service; \
        done; \
    done

docker-prod: check-swarm-init
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml up --force-recreate $(ARGS)

docker-prod-down: check-swarm-init
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml down -v $(ARGS)
