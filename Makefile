PLUGIN_NAME = conditional-meta-plugin
VERSION = v0.1.0

.PHONY: test build clean lint dev-setup help

# Default target
help: ## Show this help message
	@echo "Traefik Conditional Meta Plugin - Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

test: ## Run all tests
	@echo "Running tests..."
	go test -v ./...
	@echo "✅ All tests passed!"

test-coverage: ## Run tests with coverage
	@echo "Running tests with coverage..."
	go test -v -cover ./...
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report generated: coverage.html"

lint: ## Run linting
	@echo "Running linter..."
	@if command -v golangci-lint >/dev/null; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
		go vet ./...; \
		go fmt ./...; \
	fi

build: ## Build the plugin (validates compilation)
	@echo "Building plugin..."
	go build -v ./...
	@echo "✅ Plugin builds successfully!"

clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -f coverage.out coverage.html
	go clean ./...
	@echo "✅ Cleaned!"

dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	mkdir -p ./plugins-local/src/github.com/carlos/traefik-conditional-meta-plugin
	cp *.go ./plugins-local/src/github.com/carlos/traefik-conditional-meta-plugin/
	cp go.mod ./plugins-local/src/github.com/carlos/traefik-conditional-meta-plugin/
	@echo "✅ Plugin files copied to plugins-local directory"
	@echo ""
	@echo "To test locally:"
	@echo "1. Start Traefik with examples/traefik-local.yml"
	@echo "2. Use examples/dynamic-config.yml for routing"
	@echo "3. Run: make test-local"

test-local: ## Test the plugin locally (requires running Traefik)
	@echo "Testing local plugin..."
	@if command -v curl >/dev/null && command -v jq >/dev/null; then \
		chmod +x examples/test.sh; \
		./examples/test.sh; \
	else \
		echo "curl and jq are required for local testing"; \
		echo "Install with: apt-get install curl jq (Ubuntu/Debian) or brew install curl jq (macOS)"; \
	fi

docker-test: ## Run tests in Docker environment
	@echo "Running tests with Docker Compose..."
	cd examples && docker-compose up -d
	@sleep 5  # Wait for services to start
	@echo "Testing..."
	@BASE_URL=http://localhost ENDPOINT=/json make test-local || true
	cd examples && docker-compose down
	@echo "✅ Docker test completed!"

validate: ## Validate plugin for Traefik catalog
	@echo "Validating plugin for Traefik catalog..."
	@echo "Checking required files..."
	@test -f .traefik.yml || (echo "❌ Missing .traefik.yml" && exit 1)
	@test -f go.mod || (echo "❌ Missing go.mod" && exit 1)
	@test -f README.md || (echo "❌ Missing README.md" && exit 1)
	@echo "Validating .traefik.yml..."
	@grep -q "displayName:" .traefik.yml || (echo "❌ Missing displayName in .traefik.yml" && exit 1)
	@grep -q "type: middleware" .traefik.yml || (echo "❌ Missing or incorrect type in .traefik.yml" && exit 1)
	@grep -q "import:" .traefik.yml || (echo "❌ Missing import in .traefik.yml" && exit 1)
	@grep -q "testData:" .traefik.yml || (echo "❌ Missing testData in .traefik.yml" && exit 1)
	@echo "Validating Go module..."
	@go mod verify
	@echo "Running tests..."
	@make test
	@echo "✅ Plugin validation passed!"
	@echo ""
	@echo "To publish to Traefik catalog:"
	@echo "1. Create a GitHub repository"
	@echo "2. Add 'traefik-plugin' topic to the repository"
	@echo "3. Tag a release: git tag $(VERSION) && git push --tags"
	@echo "4. The catalog will discover it automatically within 30 minutes"

release: validate ## Create a release
	@echo "Creating release $(VERSION)..."
	@git tag -a $(VERSION) -m "Release $(VERSION)"
	@echo "✅ Release $(VERSION) created!"
	@echo "Push with: git push origin --tags"

format: ## Format code
	@echo "Formatting code..."
	go fmt ./...
	@echo "✅ Code formatted!"

mod-tidy: ## Tidy go modules
	@echo "Tidying go modules..."
	go mod tidy
	@echo "✅ Go modules tidied!"

all: format mod-tidy lint test build ## Run all checks

traefik-local: dev-setup ## Start Traefik locally for development
	@echo "Starting Traefik locally..."
	@if command -v traefik >/dev/null; then \
		traefik --configfile=examples/traefik-local.yml; \
	else \
		echo "Traefik not found. Install from: https://github.com/traefik/traefik/releases"; \
		echo "Or run with Docker: make docker-dev"; \
	fi

docker-dev: dev-setup ## Start development environment with Docker
	@echo "Starting development environment with Docker..."
	cd examples && docker-compose -f docker-compose.yml up -d traefik
	@echo "✅ Traefik started at http://localhost (dashboard: http://localhost:8080)"
	@echo "Test with: make test-local"
	@echo "Stop with: cd examples && docker-compose down"
