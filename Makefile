.PHONY: help build test run clean

help:
	@echo "Docker Model Runner - Development Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build    Build Docker image locally"
	@echo "  test     Build and run full test suite"
	@echo "  run      Run Docker container on port 5000"
	@echo "  clean    Stop and remove containers/images"
	@echo ""

build:
	@echo "Building Docker image..."
	docker build -t model-runner:local .
	@echo "✓ Build complete"

test: build
	@echo "Testing Docker image..."
	@echo "Starting container..."
	docker run -d --name test-model-runner -p 5000:5000 model-runner:local
	@echo "Waiting for container to be ready..."
	@sleep 30
	@echo "Testing health endpoint..."
	@curl -f http://localhost:5000/health || (docker logs test-model-runner && exit 1)
	@echo ""
	@echo "Testing generate endpoint..."
	@curl -X POST http://localhost:5000/generate \
		-H "Content-Type: application/json" \
		-d '{"prompt": "Test", "max_length": 20}' || (docker logs test-model-runner && exit 1)
	@echo ""
	@echo "Cleaning up..."
	@docker stop test-model-runner
	@docker rm test-model-runner
	@echo "✓ All tests passed"

run: build
	@echo "Running container on http://localhost:5000"
	@echo "Press Ctrl+C to stop"
	@echo ""
	docker run --rm -p 5000:5000 --name model-runner model-runner:local

clean:
	@echo "Cleaning up..."
	-@docker stop model-runner test-model-runner 2>/dev/null || true
	-@docker rm model-runner test-model-runner 2>/dev/null || true
	-@docker rmi model-runner:local 2>/dev/null || true
	@echo "✓ Cleanup complete"