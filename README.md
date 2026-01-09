# Docker Model Runner with Hugging Face

A simplified Docker-based model runner that uses Hugging Face models with automated GitHub Actions CI/CD pipeline for building and pushing Docker images on code changes.

## Overview

This project demonstrates how to:
- Run Hugging Face models inside Docker containers
- Automatically build new Docker images when code changes
- Test locally before deploying
- Use GitHub Actions for CI/CD automation

## Prerequisites

- Docker Desktop installed and running
- GitHub account
- Docker Hub account (for storing images)
- Git installed locally

## Project Structure

```
docker-model-runner/
├── README.md
├── QUICKSTART.md
├── ADVANCED.md
├── LOCAL_TESTING.md
├── .gitignore
├── .dockerignore
├── .hadolint.yaml
├── Dockerfile
├── requirements.txt
├── app.py
├── lint-check.sh
├── Makefile
└── .github/
    └── workflows/
        └── docker-build.yml
```

## Features

- Lightweight Python Flask API
- Hugging Face text generation model integration
- Multi-stage Docker build for optimized image size
- Security-hardened container (non-root user, minimal base image)
- Built-in health checks and proper signal handling
- Automated Docker image building on push with comprehensive CI/CD
- Automated testing and vulnerability scanning
- Local testing capabilities
- Production-ready configuration

## Docker Security Features

The Dockerfile implements several security best practices:

- **Multi-stage build**: Separates build dependencies from runtime, reducing attack surface
- **Non-root user**: Application runs as unprivileged user 'appuser'
- **Minimal base image**: Uses python:3.11-slim to minimize vulnerabilities
- **Security updates**: Automatically applies latest security patches
- **Health checks**: Built-in container health monitoring
- **Signal handling**: Uses tini for proper process management
- **No cache directories**: Prevents bloat and potential security issues
- **Immutable layers**: Build-time security with minimal runtime modifications

## Quick Start

See [QUICKSTART.md](QUICKSTART.md) for detailed local testing instructions.

## Local Testing

Before pushing to GitHub, test everything locally:

```bash
# Install development dependencies
make install-dev

# Run linting checks
make lint

# Auto-fix formatting issues
make format

# Build and test Docker image
make test

# Test GitHub Actions locally (requires act)
make test-actions
```

For complete local testing instructions, including GitHub Actions simulation with `act`, see [LOCAL_TESTING.md](LOCAL_TESTING.md).

## GitHub Actions Workflow

The project includes a comprehensive automated CI/CD pipeline that:

### Stage 1: Lint and Validate
- Python code formatting checks (Black, isort)
- Code quality analysis (Flake8)
- Dockerfile validation (Hadolint)

### Stage 2: Security Scanning
- Filesystem vulnerability scanning (Trivy)
- Python dependency security checks (Safety)
- Results uploaded to GitHub Security tab

### Stage 3: Build and Test
- Multi-stage Docker build with layer caching
- Container health checks
- API endpoint testing
- Image vulnerability scanning

### Stage 4: Push to Registry
- Automated tagging (branch name, commit SHA, latest)
- Multi-platform support
- Build metadata and labels
- Digest generation for verification

### Stage 5: Post-Deployment
- Docker Hub description updates
- Deployment summaries
- Success notifications

## Setup Instructions

### Step 1: Clone or Create Repository

Create a new GitHub repository and clone it locally:

```bash
git clone https://github.com/YOUR_USERNAME/docker-model-runner.git
cd docker-model-runner
```

### Step 2: Add Project Files

Copy all project files into your repository directory (see Project Structure above).

### Step 3: Configure Docker Hub Secrets

In your GitHub repository, add the following secrets:

1. Go to Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Add these secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token

To create a Docker Hub access token:
1. Log in to Docker Hub
2. Go to Account Settings > Security
3. Click "New Access Token"
4. Give it a description and click "Generate"
5. Copy the token immediately

### Step 4: Update Docker Hub Repository Name

Edit `.github/workflows/docker-build.yml` and replace `YOUR_DOCKERHUB_USERNAME/docker-model-runner` with your actual Docker Hub username.

### Step 5: Test Locally

Follow the [QUICKSTART.md](QUICKSTART.md) guide to test everything works locally before pushing.

### Step 6: Push to GitHub

```bash
git add .
git commit -m "Initial commit: Docker Model Runner setup"
git push origin main
```

### Step 7: Monitor GitHub Actions

1. Go to your repository on GitHub
2. Click the "Actions" tab
3. Watch your workflow run
4. Verify the build completes successfully

### Step 8: Verify Docker Hub

Check your Docker Hub account to confirm the new image has been pushed.

## Using the Model Runner

### Running Locally

```bash
docker build -t model-runner .
docker run -p 5000:5000 model-runner
```

### Testing the API

```bash
curl -X POST http://localhost:5000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Once upon a time", "max_length": 50}'
```

### Running from Docker Hub

After GitHub Actions builds and pushes your image:

```bash
docker pull YOUR_DOCKERHUB_USERNAME/docker-model-runner:latest
docker run -p 5000:5000 YOUR_DOCKERHUB_USERNAME/docker-model-runner:latest
```

## Making Changes

When you make code changes:

1. Edit your files locally
2. Test locally using Docker
3. Commit and push to GitHub:
   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin main
   ```
4. GitHub Actions automatically builds a new image
5. New image is available on Docker Hub within minutes

## Workflow Explanation

The GitHub Actions workflow (`.github/workflows/docker-build.yml`) is a multi-stage pipeline:

### Job 1: Lint and Validate (lint-and-validate)
- **Black**: Checks Python code formatting
- **isort**: Validates import ordering
- **Flake8**: Analyzes code quality and style
- **Hadolint**: Validates Dockerfile best practices

### Job 2: Security Scanning (security-scan)
- **Trivy Filesystem Scan**: Checks for vulnerabilities in code and dependencies
- **Safety Check**: Scans Python packages for known security issues
- **SARIF Upload**: Integrates results with GitHub Security tab

### Job 3: Build and Test (build-and-test)
- **Docker Layer Caching**: Speeds up builds by reusing unchanged layers
- **Test Build**: Creates image without pushing
- **Container Testing**: Starts container and validates functionality
- **Health Check**: Verifies /health endpoint responds correctly
- **API Testing**: Tests /generate endpoint with sample request
- **Vulnerability Scan**: Scans built image for security issues

### Job 4: Push Image (push-image)
- **Multiple Tags**: Creates branch, SHA, and latest tags
- **Metadata**: Adds OCI-compliant labels and annotations
- **Multi-platform**: Supports linux/amd64 (can be extended)
- **Build Summary**: Generates GitHub Actions summary with details

### Job 5: Post-Deployment (post-deployment)
- **Docker Hub Sync**: Updates repository description
- **Documentation**: Creates deployment summary
- **Notifications**: Logs success messages and image details

### Workflow Triggers
- **Push to main/develop**: Automatically builds and deploys
- **Pull Requests**: Runs tests without pushing images
- **Manual Dispatch**: Allows custom tags via workflow_dispatch
- **Path Filters**: Skips builds for documentation-only changes

## Troubleshooting

### GitHub Actions Fails

**Linting Stage Issues:**
- Code formatting errors: Run `black app.py` locally to fix
- Import order issues: Run `isort app.py` locally
- Hadolint warnings: Review Dockerfile against best practices

**Security Scan Failures:**
- Critical vulnerabilities found: Update dependencies in requirements.txt
- Safety API issues: SAFETY_API_KEY secret is optional
- Trivy scan errors: Check network connectivity

**Build and Test Failures:**
- Health check timeout: Increase sleep time or start-period in Dockerfile
- API test failures: Check app.py for errors in /generate endpoint
- Container won't start: Review container logs in Actions output

**Push Stage Issues:**
- Authentication errors: Verify DOCKERHUB_USERNAME and DOCKERHUB_TOKEN secrets
- Registry errors: Check Docker Hub service status
- Tag conflicts: Ensure Docker Hub repository name is correct

### Local Build Fails

- Ensure Docker Desktop is running
- Check that all files are present
- Verify requirements.txt has correct dependencies
- Multi-stage build requires Docker 17.05+

### Model Download Issues

- First run downloads the model (may take time)
- Ensure stable internet connection
- Check Hugging Face service status
- Model cache stored in /home/appuser/.cache

### Permission Issues

- Container runs as non-root user 'appuser'
- Volume mounts may need explicit permissions
- Use `--user` flag if mounting volumes

## Customization

### Using a Different Model

Edit `app.py` and change the model name:

```python
model_name = "your-preferred-model"
```

### Changing the Port

Edit `Dockerfile` and `app.py` to use a different port.

### Adding More Endpoints

Add new routes in `app.py` following the Flask pattern.

## Best Practices

1. Always test locally before pushing to GitHub
2. Use meaningful commit messages
3. Review GitHub Actions logs after each push
4. Keep your Docker Hub token secure
5. Regularly update dependencies in requirements.txt

## Additional Resources

- [ADVANCED.md](ADVANCED.md) - In-depth guide to multi-stage builds, security hardening, and workflow customization
- [Docker Documentation](https://docs.docker.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Hugging Face Documentation](https://huggingface.co/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Trivy Security Scanner](https://aquasecurity.github.io/trivy/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

