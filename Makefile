.PHONY: help run test docker-build docker-run docker-stop rag-update flutter-sync-assets flutter-run flutter-build-apk

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

run: ## Start API server (FastAPI)
	uvicorn src.main:app --host 0.0.0.0 --port 7860 --reload

test: ## Run tests
	pytest tests/ -v

docker-build: ## Build Docker image
	docker build -t vetvoice-rag .

docker-run: ## Run Docker container
	docker compose up -d

docker-stop: ## Stop Docker container
	docker compose down

rag-update: ## Rebuild RAG knowledge base locally
	python scripts/build_rag.py

flutter-sync-assets: ## Copy assets/data -> flutter/assets/data (required before Flutter build)
	@mkdir -p flutter/assets/data
	cp -r assets/data/. flutter/assets/data/
	@echo "Flutter assets synced from assets/data"

flutter-run: ## Run Flutter app (debug)
	$(MAKE) flutter-sync-assets
	cd flutter && flutter run

flutter-build-apk: ## Build Flutter release APK (syncs assets first)
	$(MAKE) flutter-sync-assets
	cd flutter && flutter build apk --release
