.PHONY: help lint format build test run clean install-dev test-actions

help:
	@echo "Docker Model Runner - Development Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build          Build Docker image"
	@echo "  test           Run Docker image tests"
	@echo "  run            Run Docker container locally"
	@echo "  clean          Remove containers and images"
	@echo "  install-dev    Install development dependencies (optional)"
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
	docker run -p 5000:5000 --name model-runner model-runner:local

clean:
	@echo "Cleaning up..."
	-docker stop model-runner test-model-runner 2>/dev/null || true
	-docker rm model-runner test-model-runner 2>/dev/null || true
	-docker rmi model-runner:local 2>/dev/null || true
	@echo "✓ Cleanup complete"

install-dev:
	@echo "Installing development dependencies..."
	pip install --upgrade pip
	pip install black isort flake8 pylint
	@echo "✓ Development dependencies installed"
	@echo ""
	@echo "Note: Linting is optional and not required for the pipeline"
	@echo "Optional: Install hadolint for Dockerfile linting"
	@echo "  macOS: brew install hadolint"
	@echo "  Linux: See https://github.com/hadolint/hadolint"