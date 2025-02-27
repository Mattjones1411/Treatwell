# Makefile for Countries Data Extraction Application

.PHONY: help setup test lint format clean build run run-tests debug docker-build docker-run

# Variables
PYTHON = python3
PIP = pip3
APP_NAME = country_extraction
DOCKER_IMAGE = countries-extraction
DOCKER_TAG = latest

help: ## Show this help menu
	@echo "Usage: make [TARGET]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Install dependencies
	pip install pyproject.toml

test: ## Run tests
	pytest src/test_$(APP_NAME).py -v

lint: ## Lint with ruff
	ruff format src/

clean: ## Remove build artifacts
	rm -rf src/__pycache__/
	rm -rf .pytest_cache/
	rm -rf terraform/terraform.tfstate
	rm -rf terraform/.terraform
	rm -rf .ruff_cache/

run: ## Run the application
	$(PYTHON) src/$(APP_NAME).py

debug: ## Run the application in debug mode
	LOGGING_LEVEL=DEBUG $(PYTHON) src/$(APP_NAME).py

docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) -f src/Dockerfile .

docker-run: ## Run Docker container with AWS credentials mounted
	docker run --rm \
		-v ~/.aws:/root/.aws \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

aws-configure: ## Configure AWS credentials
	aws configure

docker-clean: ## Remove all Docker containers and images related to this repo
	docker ps -q | xargs -r docker stop
	docker ps -aq | xargs -r docker rm
	docker images -q "$(DOCKER_IMAGE)" | xargs -r docker rmi -f