# Quick Start Guide

This guide walks you through testing the Docker Model Runner locally before setting up GitHub Actions automation.

## Step 1: Verify Prerequisites

Check that you have everything installed:

```bash
docker --version
git --version
python --version
```

You should see version numbers for each command. Docker Desktop should be running (check your system tray or menu bar).

## Step 2: Create Project Directory

```bash
mkdir docker-model-runner
cd docker-model-runner
```

## Step 3: Create Application File

Create a file named `app.py` with the following content:

```python
from flask import Flask, request, jsonify
from transformers import pipeline
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize model (this happens once when container starts)
logger.info("Loading model...")
generator = pipeline('text-generation', model='distilgpt2')
logger.info("Model loaded successfully")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/generate', methods=['POST'])
def generate():
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        max_length = data.get('max_length', 50)
        
        if not prompt:
            return jsonify({"error": "No prompt provided"}), 400
        
        logger.info(f"Generating text for prompt: {prompt[:50]}...")
        result = generator(prompt, max_length=max_length, num_return_sequences=1)
        
        return jsonify({
            "prompt": prompt,
            "generated_text": result[0]['generated_text']
        }), 200
        
    except Exception as e:
        logger.error(f"Error generating text: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

## Step 4: Create Requirements File

Create `requirements.txt`:

```
flask==3.0.0
transformers==4.35.0
torch==2.1.0
```

## Step 5: Create Dockerfile

Create `Dockerfile` with multi-stage build:

```dockerfile
# Multi-stage build for security and optimization
# Stage 1: Builder stage
FROM python:3.11-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    tini \
    curl \
    && rm -rf /var/lib/apt/lists/* && \
    apt-get clean

RUN groupadd -r appuser && \
    useradd -r -g appuser -s /sbin/nologin -c "Application user" appuser

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv

COPY --chown=appuser:appuser app.py .

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN mkdir -p /home/appuser/.cache && \
    chown -R appuser:appuser /home/appuser

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["python", "app.py"]
```

**Key features of this Dockerfile:**
- Multi-stage build reduces image size
- Non-root user for security
- Health checks for monitoring
- Proper signal handling with tini

## Step 6: Create Docker Ignore File

Create `.dockerignore`:

```
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv
pip-log.txt
pip-delete-this-directory.txt
.git
.gitignore
README.md
QUICKSTART.md
.github
*.md
```

## Step 7: Create Git Ignore File

Create `.gitignore`:

```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Models (if downloading locally)
models/
*.bin
*.safetensors

# Logs
*.log
logs/

# Docker
.dockerignore
```

## Step 8: Build Docker Image

Build your Docker image:

```bash
docker build -t model-runner:test .
```

This will take a few minutes the first time as it downloads dependencies.

Expected output:
- Multiple steps showing package installations
- Final message: "Successfully tagged model-runner:test"

## Step 9: Run Docker Container

Start the container:

```bash
docker run -p 5000:5000 model-runner:test
```

Expected output:
- "Loading model..."
- "Model loaded successfully"
- "Running on http://0.0.0.0:5000"

Keep this terminal window open.

## Step 10: Test the Health Endpoint

Open a new terminal window and test the health endpoint:

```bash
curl http://localhost:5000/health
```

Expected output:
```json
{"status":"healthy"}
```

## Step 11: Test Text Generation

Test the main generation endpoint:

```bash
curl -X POST http://localhost:5000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "The future of AI is", "max_length": 50}'
```

Expected output:
```json
{
  "prompt": "The future of AI is",
  "generated_text": "The future of AI is... [generated text continues]"
}
```

## Step 12: Test with Different Prompts

Try various prompts to ensure the model works correctly:

```bash
curl -X POST http://localhost:5000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Once upon a time", "max_length": 100}'
```

## Step 13: Stop the Container

Press `Ctrl+C` in the terminal where the container is running, or in a new terminal:

```bash
docker ps
docker stop [CONTAINER_ID]
```

## Step 14: Create GitHub Actions Workflow

Create the directory structure:

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/docker-build.yml`:

```yaml
name: Build, Test, and Push Docker Image

on:
  push:
    branches:
      - main
      - develop
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    branches:
      - main
  workflow_dispatch:
    inputs:
      tag:
        description: 'Custom tag for the image'
        required: false
        default: ''

env:
  DOCKER_IMAGE: YOUR_DOCKERHUB_USERNAME/docker-model-runner
  PYTHON_VERSION: '3.11'

jobs:
  lint-and-validate:
    name: Lint and Validate Code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      - name: Install linting dependencies
        run: |
          python -m pip install --upgrade pip
          pip install flake8 black isort
      - name: Run Flake8 linter
        run: flake8 app.py --max-line-length=100
        continue-on-error: true

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    needs: lint-and-validate
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'

  build-and-test:
    name: Build and Test Docker Image
    runs-on: ubuntu-latest
    needs: security-scan
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build Docker image for testing
        uses: docker/build-push-action@v5
        with:
          context: .
          load: true
          tags: ${{ env.DOCKER_IMAGE }}:test
      - name: Test Docker image - Health check
        run: |
          docker run -d --name test-container -p 5000:5000 ${{ env.DOCKER_IMAGE }}:test
          sleep 30
          curl -f http://localhost:5000/health || exit 1

  push-image:
    name: Push Docker Image to Registry
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.event_name != 'pull_request'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_IMAGE }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

**Important:** Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username in TWO places:
1. In the `env:` section at the top
2. This will automatically apply to all references throughout the workflow

## Step 15: Initialize Git Repository

```bash
git init
git add .
git commit -m "Initial commit: Docker Model Runner"
```

## Step 16: Connect to GitHub

Create a new repository on GitHub, then:

```bash
git remote add origin https://github.com/YOUR_USERNAME/docker-model-runner.git
git branch -M main
```

## Step 17: Set Up Docker Hub Secrets

Before pushing, set up secrets in your GitHub repository:

1. Go to your repository on GitHub
2. Click Settings
3. Navigate to Secrets and variables > Actions
4. Click "New repository secret"
5. Add `DOCKERHUB_USERNAME` with your Docker Hub username
6. Add `DOCKERHUB_TOKEN` with your Docker Hub access token

To get a Docker Hub token:
1. Log in to hub.docker.com
2. Click your username > Account Settings
3. Go to Security > New Access Token
4. Name it "GitHub Actions" and click Generate
5. Copy the token immediately

## Step 18: Push to GitHub

```bash
git push -u origin main
```

## Step 19: Verify GitHub Actions

1. Go to your repository on GitHub
2. Click the "Actions" tab
3. You should see your workflow running with multiple jobs
4. Watch the progress of each stage:
   - Lint and Validate (code quality checks)
   - Security Scan (vulnerability detection)
   - Build and Test (Docker image creation and testing)
   - Push Image (upload to Docker Hub)
5. Click on each job to see detailed logs
6. Wait for all jobs to complete (green checkmarks)

**Expected workflow duration:** 5-8 minutes for first run, 2-4 minutes with caching.

## Step 20: Verify Docker Hub

1. Log in to hub.docker.com
2. Go to Repositories
3. You should see `docker-model-runner` with a new image
4. Check the tags (should include `latest` and a SHA tag)

## Testing the Automated Build

Make a small change to test the automation:

```bash
# Edit app.py to add a version endpoint
echo '
@app.route("/version", methods=["GET"])
def version():
    return jsonify({"version": "1.0.1"}), 200
' >> app.py

git add app.py
git commit -m "Add version endpoint"
git push origin main
```

Watch GitHub Actions automatically build and push a new image.

## Troubleshooting

### Docker Build Fails Locally

- Ensure Docker Desktop is running
- Check you have enough disk space (need ~2GB free)
- Multi-stage build requires Docker 17.05 or higher
- Try `docker system prune` to clean up old images
- Check Docker version: `docker --version`

### Health Check Fails

- Container needs 30-60 seconds to start
- Model downloads on first run
- Check container logs: `docker logs [CONTAINER_ID]`
- Increase wait time in health check test

### GitHub Actions Lint Stage Fails

- Run linters locally before pushing:
  ```bash
  pip install flake8 black isort
  black --check app.py
  flake8 app.py
  ```
- Fix issues and commit again

### GitHub Actions Security Scan Fails

- Check for vulnerable dependencies
- Update package versions in requirements.txt
- Review Trivy output in Actions logs
- Critical vulnerabilities will block the build

### GitHub Actions Build Stage Fails

- Verify Dockerfile syntax
- Check all COPY commands reference existing files
- Review build logs for specific errors
- Test multi-stage build locally first

### Cannot Connect to Container

- Verify port 5000 is not in use: `lsof -i :5000`
- Check container is running: `docker ps`
- Review container logs: `docker logs [CONTAINER_ID]`

### GitHub Actions Fails

- Verify secrets are set correctly
- Check Docker Hub username in workflow file
- Review Actions logs for specific errors

### Model Loading Takes Long

- First run downloads the model (3-5 minutes)
- Subsequent runs use cached model
- Check internet connection stability

## Next Steps

Now that everything is working:

1. Customize the model in `app.py`
2. Add more API endpoints
3. Improve error handling
4. Add tests
5. Set up deployment to cloud services

Refer to the main README.md for additional configuration options and best practices.