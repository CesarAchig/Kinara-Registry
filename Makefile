.PHONY: all help build build-server build-cli dev-server dev-ui test lint lint-go lint-ui clean

# Variables
BINARY_SERVER=bin/kinara
BINARY_CLI=bin/kinara-cli
WEB_DIR=web

help: ## Muestra este menú de ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

build: build-ui build-server build-cli ## Compila la UI y todos los binarios de Go

build-ui: ## Compila el Frontend SPA estático usando Bun y Vite
	@echo "📦 Compilando Frontend con Bun..."
	@cd $(WEB_DIR) && bun install && bun run build

build-server: ## Compila el binario unificado del servidor Kinara (con la UI embebida)
	@echo "🔨 Compilando Kinara Server..."
	@mkdir -p bin
	@go build -ldflags="-s -w" -o $(BINARY_SERVER) ./cmd/kinara

build-cli: ## Compila la herramienta CLI de desarrollo y administración
	@echo "🔨 Compilando Kinara CLI..."
	@mkdir -p bin
	@go build -ldflags="-s -w" -o $(BINARY_CLI) ./cmd/kinara-cli

dev-server: ## Inicia el backend en modo desarrollo con recarga automática (Air)
	@if command -v air > /dev/null; then \
		air; \
	else \
		go run ./cmd/kinara server --mode=all; \
	fi

dev-ui: ## Inicia el servidor de desarrollo de Vite con Bun
	@echo "🌐 Iniciando UI en http://localhost:5173 ..."
	@cd $(WEB_DIR) && bun run dev

test: ## Ejecuta las pruebas unitarias y de integración de Go
	@echo "🧪 Ejecutando tests..."
	@go test -v -race ./...

lint: lint-go lint-ui ## Ejecuta todos los linters (Go y Frontend)

lint-go: ## Ejecuta el linter de Go (golangci-lint o go vet)
	@echo "🔍 Analizando código Go con golangci-lint..."
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run ./...; \
	else \
		echo "⚠️  golangci-lint no está en el PATH del host. Ejecutando go vet..."; \
		go vet ./...; \
	fi

lint-ui: ## Ejecuta el linter de Frontend (ESLint)
	@echo "🔍 Analizando código Frontend con ESLint..."
	@if command -v bun > /dev/null; then \
		cd $(WEB_DIR) && bun run lint; \
	elif command -v npm > /dev/null; then \
		cd $(WEB_DIR) && npm run lint; \
	else \
		echo "⚠️  Bun/npm no está en el PATH del host (ejecutar dentro del Dev Container)."; \
	fi

clean: ## Limpia binarios generados y cachés de compilación
	@echo "🧹 Limpiando binarios y temporales..."
	@rm -rf bin/ $(WEB_DIR)/dist/ $(WEB_DIR)/node_modules/ tmp/
