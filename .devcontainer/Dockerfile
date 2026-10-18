FROM mcr.microsoft.com/devcontainers/go:2-1.27-trixie

# 1. Instalar utilidades del sistema y dependencias para SQLite (para probar el modo embebido WAL)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        sqlite3 \
        libsqlite3-dev \
        make \
        curl \
        jq \
        git \
        ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Instalar Bun globalmente para el frontend (React 19 + Vite + Tailwind + shadcn)
ENV BUN_INSTALL=/usr/local
RUN curl -fsSL https://bun.sh/install | bash \
    && chmod 755 /usr/local/bin/bun /usr/local/bin/bunx

# 3. Herramientas de desarrollo Go instaladas para el usuario 'vscode'
# - air: Live-reloading para recargar el backend Go automáticamente al guardar cambios
# - golangci-lint: Linter estricto de Go
USER vscode
RUN go install github.com/air-verse/air@latest \
    && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
USER root
