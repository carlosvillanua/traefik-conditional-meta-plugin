#!/bin/bash

echo "🚀 Setting up clean Docker Compose test environment for Traefik Conditional Meta Plugin"
echo "=============================================================================="

# Stop any existing containers
echo "📦 Stopping existing containers..."
docker-compose -f docker-compose-clean.yml down 2>/dev/null || true

# Remove traefik network if it exists
echo "🌐 Cleaning up networks..."
docker network rm traefik 2>/dev/null || true

# Create fresh network
echo "🌐 Creating traefik network..."
docker network create traefik

# Start services
echo "🚀 Starting Traefik and httpbin..."
docker-compose -f docker-compose-clean.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
echo "✅ Checking service status..."
docker-compose -f docker-compose-clean.yml ps

echo ""
echo "🧪 Your plugin test environment is ready!"
echo ""
echo "Test commands:"
echo "  Without metadata: curl \"http://httpbin.localhost:8084/json\""
echo "  With metadata:    curl \"http://httpbin.localhost:8084/json?include=meta\""
echo ""
echo "Dashboard: http://localhost:8085"
echo ""
echo "To view logs: docker-compose -f docker-compose-clean.yml logs -f traefik"