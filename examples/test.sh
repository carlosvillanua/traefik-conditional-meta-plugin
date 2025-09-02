#!/bin/bash

echo "🚀 Testing Traefik Conditional Meta Plugin"
echo "=========================================="

# Test without metadata
echo ""
echo "📝 Testing JSON endpoint with metadata:"
curl -s "http://httpbin.localhost/json?include=meta" | jq .meta

echo ""
echo "✅ Tests completed!"