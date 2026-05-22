.PHONY: help run test docker-build docker-run docker-stop rag-update flutter-run flutter-build-apk

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

run: ## Start API server
	uvicorn src.main:app --host 0.0.0.0 --port 7860 --reload

test: ## Run tests
	pytest tests/ -v

docker-build: ## Build Docker image
	docker build -t vetvoice-rag .

docker-run: ## Run Docker container
	docker compose up -d

docker-stop: ## Stop Docker container
	docker compose down

rag-update: ## Update RAG knowledge base
	python scripts/build_rag.py

flutter-run: ## Run Flutter app (debug)
	cd flutter && flutter run

flutter-build-apk: ## Build Flutter APK
	cd flutter && flutter build apk --release
