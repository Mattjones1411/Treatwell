# Makefile for Countries Data Extraction Application

.PHONY: help setup test lint format clean build run run-tests debug docker-build docker-shell

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
	poetry install -r requirements.txt

setup-dev: setup ## Install development dependencies
	poetry install -r requirements.txt[dev]

test: ## Run tests
	pytest test_$(APP_NAME).py -v

test-coverage: ## Run tests with coverage report
	pytest test_$(APP_NAME).py --cov=$(APP_NAME) --cov-report=term --cov-report=html

lint: ## Check code style with flake8 and pylint
	flake8 src/$(APP_NAME).py
	pylint src/$(APP_NAME).py

format: ## Format code with black
	black src/

clean: ## Remove build artifacts
	rm -rf src/__pycache__/
	rm -rf terraform/.terraform
	rm -rf terraform/terraform.tfstate

run: ## Run the application
	$(PYTHON) $(APP_NAME).py

debug: ## Run the application in debug mode
	LOGGING_LEVEL=DEBUG $(PYTHON) $(APP_NAME).py

docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-shell: ## Get a shell inside the Docker container
	docker run --rm -it $(DOCKER_IMAGE):$(DOCKER_TAG) /bin/bash

aws-configure: ## Configure AWS credentials
	aws configure
