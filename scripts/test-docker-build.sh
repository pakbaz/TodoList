#!/bin/bash

# Local Docker build test script for TodoList
# This script helps debug Docker build issues before deploying via GitHub Actions

set -e

echo "🐳 Testing Docker build locally..."

# Clean up any existing containers
echo "🧹 Cleaning up existing containers..."
docker stop todolist-test 2>/dev/null || true
docker rm todolist-test 2>/dev/null || true

# Build the image
echo "🔨 Building Docker image..."
DOCKER_BUILDKIT=1 docker build \
  --progress=plain \
  --no-cache \
  -t todolist-app:test \
  .

# Test the image
echo "🧪 Testing the built image..."
docker run -d \
  --name todolist-test \
  -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Development \
  -e ConnectionStrings__SqliteConnection="Data Source=:memory:" \
  todolist-app:test

# Wait for the app to start
echo "⏳ Waiting for application to start..."
sleep 10

# Test health endpoint
echo "🔍 Testing health endpoint..."
if curl -f http://localhost:8080/health; then
    echo "✅ Application is healthy!"
else
    echo "❌ Application health check failed"
    docker logs todolist-test
    exit 1
fi

# Test API endpoint
echo "🔍 Testing API endpoint..."
if curl -f http://localhost:8080/mcp/todos; then
    echo "✅ API endpoint is working!"
else
    echo "❌ API endpoint test failed"
    docker logs todolist-test
    exit 1
fi

# Clean up
echo "🧹 Cleaning up test container..."
docker stop todolist-test
docker rm todolist-test

echo "✅ Docker build test completed successfully!"
echo "🚀 You can now push to GitHub to trigger the deployment workflow."
