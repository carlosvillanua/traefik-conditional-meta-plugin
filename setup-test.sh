#!/bin/bash

echo "🚀 Setting up clean Docker Compose test environment for Traefik Conditional Meta Plugin"
echo "=============================================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect docker compose command
detect_docker_compose() {
    if command_exists "docker compose"; then
        echo "docker compose"
    elif command_exists "docker-compose"; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# Check dependencies
echo "🔍 Checking dependencies..."
if ! command_exists docker; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

DOCKER_COMPOSE_CMD=$(detect_docker_compose)
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    echo "❌ Error: Docker Compose is not installed."
    echo "   Install Docker Compose or use Docker Desktop which includes it."
    exit 1
fi

echo "✅ Found Docker and Docker Compose"

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker daemon is not running. Please start Docker."
    exit 1
fi

# Stop any existing containers
echo "📦 Stopping existing containers..."
$DOCKER_COMPOSE_CMD -f docker-compose-clean.yml down 2>/dev/null || true

# Remove traefik network if it exists
echo "🌐 Cleaning up networks..."
docker network rm traefik 2>/dev/null || true

# Setup plugin directory structure
echo "📁 Setting up plugin directory structure..."
mkdir -p plugins-local/src/github.com/carlosvillanua/conditionalmeta

# Check if required files exist
REQUIRED_FILES=("conditional_meta_plugin.go" "conditional_meta_plugin_test.go" "go.mod" ".traefik.yml")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Required file '$file' not found in current directory."
        echo "   Make sure you're running this script from the plugin root directory."
        exit 1
    fi
done

# Copy plugin files to expected location
echo "📋 Copying plugin files..."
cp conditional_meta_plugin.go plugins-local/src/github.com/carlosvillanua/conditionalmeta/ || {
    echo "❌ Error: Failed to copy plugin files"
    exit 1
}
cp conditional_meta_plugin_test.go plugins-local/src/github.com/carlosvillanua/conditionalmeta/ || {
    echo "❌ Error: Failed to copy test files"
    exit 1
}
cp go.mod plugins-local/src/github.com/carlosvillanua/conditionalmeta/ || {
    echo "❌ Error: Failed to copy go.mod"
    exit 1
}
cp .traefik.yml plugins-local/src/github.com/carlosvillanua/conditionalmeta/ || {
    echo "❌ Error: Failed to copy .traefik.yml"
    exit 1
}

echo "✅ Plugin files copied successfully"

# Create fresh network
echo "🌐 Creating traefik network..."
docker network create traefik || {
    echo "❌ Error: Failed to create Docker network"
    exit 1
}

# Check if docker-compose-clean.yml exists
if [ ! -f "docker-compose-clean.yml" ]; then
    echo "❌ Error: docker-compose-clean.yml not found in current directory."
    echo "   Make sure you're running this script from the plugin root directory."
    exit 1
fi

# Start services
echo "🚀 Starting Traefik and httpbin..."
$DOCKER_COMPOSE_CMD -f docker-compose-clean.yml up -d || {
    echo "❌ Error: Failed to start services"
    exit 1
}

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
echo "✅ Checking service status..."
$DOCKER_COMPOSE_CMD -f docker-compose-clean.yml ps

# Verify services are actually running
if ! $DOCKER_COMPOSE_CMD -f docker-compose-clean.yml ps | grep -q "Up"; then
    echo "❌ Error: Services failed to start properly"
    echo "📋 Check logs with: $DOCKER_COMPOSE_CMD -f docker-compose-clean.yml logs"
    exit 1
fi

echo ""
echo "🧪 Your plugin test environment is ready!"
echo ""
echo "Test commands:"
echo "  Without metadata: curl \"http://httpbin.localhost:8084/json\""
echo "  With metadata:    curl \"http://httpbin.localhost:8084/json?include=meta\""
echo ""
echo "Dashboard: http://localhost:8085"
echo ""
echo "Useful commands:"
echo "  View logs:     $DOCKER_COMPOSE_CMD -f docker-compose-clean.yml logs -f traefik"
echo "  Stop services: $DOCKER_COMPOSE_CMD -f docker-compose-clean.yml down"
echo "  Restart setup: ./setup-test.sh"
echo ""
echo "💡 Tip: If tests fail, check if httpbin.localhost resolves to 127.0.0.1 in your /etc/hosts file"