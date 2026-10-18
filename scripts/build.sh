#!/usr/bin/env bash
set -e

echo "🚀 Iniciando build unificado de Kinara Registry..."

# 1. Build de la UI si bun está instalado
if command -v bun > /dev/null; then
    echo "📦 Compilando Frontend (web) con Bun..."
    cd web
    bun install
    bun run build
    cd ..
else
    echo "⚠️  Bun no encontrado en el host. Saltando compilación de UI..."
fi

# 2. Compilar binarios en Go
echo "🔨 Compilando servidor Kinara y CLI..."
mkdir -p bin
go build -ldflags="-s -w" -o bin/kinara ./cmd/kinara
go build -ldflags="-s -w" -o bin/kinara-cli ./cmd/kinara-cli

echo "✅ Build completado exitosamente en ./bin"
