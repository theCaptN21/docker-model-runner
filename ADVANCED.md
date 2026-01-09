# Advanced Features and Configuration

This document provides in-depth information about the advanced features implemented in the Docker Model Runner project.

## Multi-Stage Docker Build

### Architecture Overview

The Dockerfile uses a two-stage build process to optimize both security and image size.

### Stage 1: Builder

**Purpose:** Compile and install dependencies in an isolated environment.

**What happens:**
- Starts with python:3.11-slim base image
- Installs build tools (gcc, build-essential)
- Creates a Python virtual environment in /opt/venv
- Installs all Python packages into the virtual environment
- This stage is discarded after the build completes

**Benefits:**
- Build tools and compilation artifacts don't end up in final image
- Reduces final image size by approximately 200-300MB
- Separates build-time from runtime dependencies

### Stage 2: Runtime

**Purpose:** Create minimal, secure runtime environment.

**What happens:**
- Starts fresh with python:3.11-slim base image
- Installs only runtime essentials (tini, curl for health checks)
- Copies pre-built virtual environment from builder stage
- Creates non-root user 'appuser'
- Sets up proper permissions and environment variables
- Copies application code

**Benefits:**
- Minimal attack surface (no build tools)
- Smaller image size (faster deployments)
- Better security isolation

### Size Comparison

- Single-stage build: ~1.2GB
- Multi-stage build: ~900MB
- Savings: ~300MB (25% reduction)

## Security Hardening

### Non-Root User Implementation

**Why it matters:**
Running containers as root is a security risk. If an attacker compromises the application, they have root access to the container.

**Implementation:**
```dockerfile
RUN groupadd -r appuser && \
    useradd -r -g appuser -s /sbin/nologin -c "Application user" appuser
```

**Key features:**
- System user (-r flag) - cannot log in directly
- No login shell (/sbin/nologin) - prevents interactive access
- Restricted group membership
- Limited file system permissions

**What this prevents:**
- Privilege escalation attacks
- System file modifications
- Installation of malicious packages
- Direct shell access

### Minimal Base Image

**Strategy:**
Using python:3.11-slim instead of full python image.

**Differences:**
- Full image: ~1.0GB base, includes compilers, dev tools
- Slim image: ~130MB base, essential packages only

**Security benefits:**
- Fewer installed packages = fewer potential vulnerabilities
- Smaller attack surface
- Faster security patching
- Reduced CVE exposure

### Tini Init System

**What is Tini:**
Tini is a minimal init system that handles signal forwarding and zombie process reaping.

**Why we need it:**
- Docker containers can have PID 1 problems
- Python doesn't handle signals properly as PID 1
- Zombie processes can accumulate

**How it helps:**
- Properly forwards SIGTERM to application
- Reaps zombie child processes
- Ensures graceful shutdowns
- Prevents resource leaks

### Health Checks

**Configuration:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3
```

**Parameters explained:**
- `interval=30s`: Check every 30 seconds
- `timeout=10s`: Health check must complete within 10 seconds
- `start-period=60s`: Grace period during startup (model loading)
- `retries=3`: Container marked unhealthy after 3 consecutive failures

**Benefits:**
- Docker can automatically restart unhealthy containers
- Orchestrators (Kubernetes, Swarm) can reroute traffic
- Monitoring systems get container health status
- Prevents serving requests to broken containers

### Environment Variables for Security

**PYTHONUNBUFFERED=1:**
- Forces Python to run in unbuffered mode
- Ensures logs appear immediately
- Important for debugging and monitoring

**PYTHONDONTWRITEBYTECODE=1:**
- Prevents Python from creating .pyc files
- Reduces container size
- Prevents potential security issues with cached bytecode

**PIP_NO_CACHE_DIR=1:**
- Disables pip's cache directory
- Reduces image size
- Prevents stale cached packages

## GitHub Actions Workflow Deep Dive

### Caching Strategy

**Docker Layer Caching:**
```yaml
- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-
```

**How it works:**
1. Before building, restores previous build cache
2. Docker reuses unchanged layers from cache
3. After build, saves new cache for next run
4. Old cache is replaced with new cache

**Benefits:**
- Reduces build time from 10+ minutes to 2-3 minutes
- Saves GitHub Actions minutes
- Faster feedback on code changes
- Lower bandwidth usage

**Cache invalidation:**
- New cache created for each commit SHA
- Falls back to most recent cache if exact match not found
- Automatically cleaned up by GitHub after 7 days

### Security Scanning with Trivy

**Filesystem Scan (Pre-build):**
Scans code and dependencies before building image.

**What it detects:**
- Vulnerable Python packages
- Outdated dependencies
- Known CVEs in libraries
- Configuration issues

**Image Scan (Post-build):**
Scans the final Docker image.

**What it detects:**
- OS package vulnerabilities
- Application dependencies
- Docker image layer issues
- Exposed sensitive data

**SARIF Integration:**
- Results uploaded to GitHub Security tab
- Creates security advisories automatically
- Enables Dependabot alerts
- Tracks vulnerabilities over time

### Multi-Tag Strategy

**Tags created automatically:**

1. **Branch tag:** `main-sha-abc123f`
   - Identifies which branch built this image
   - Useful for tracking deployments

2. **Commit SHA tag:** `sha-abc123f`
   - Immutable reference to exact code version
   - Enables precise rollbacks

3. **Latest tag:** `latest`
   - Only on main branch
   - Points to most recent production build

4. **Custom tag:** Manual workflow dispatch
   - For releases or special deployments
   - Example: `v1.0.0`, `staging`, `hotfix-123`

**Benefits:**
- Easy rollback to any previous version
- Clear deployment history
- Semantic versioning support
- Development vs production separation

### Testing Strategy

**Health Check Testing:**
```yaml
- name: Test Docker image - Health check
  run: |
    max_attempts=10
    attempt=1
    while [ $attempt -le $max_attempts ]; do
      if curl -f http://localhost:5000/health; then
        exit 0
      fi
      sleep 5
      attempt=$((attempt + 1))
    done
    exit 1
```

**Why retry logic:**
- Model loading takes time
- First request may be slow
- Network might be establishing
- Prevents false failures

**API Testing:**
```yaml
response=$(curl -X POST http://localhost:5000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Test prompt", "max_length": 30}')
```

**Validates:**
- API is responding
- JSON parsing works
- Model inference succeeds
- Response format is correct

### Continuous Integration Flow

**Pull Request Flow:**
1. Lint and validate code
2. Run security scans
3. Build and test image
4. **Do NOT push** (testing only)
5. Report results in PR

**Main Branch Flow:**
1. Lint and validate code
2. Run security scans
3. Build and test image
4. **Push to Docker Hub**
5. Update documentation
6. Create deployment summary

### Build Summary Generation

**What gets generated:**
- Image digest (SHA256 hash)
- All tags created
- Build timestamp
- Pull and run commands
- GitHub Actions summary page

**Example output:**
```
## Docker Image Build Summary

**Image Digest:** `sha256:abc123...`

**Tags:**
```
your-username/docker-model-runner:main-sha-abc123f
your-username/docker-model-runner:latest
```

**Build Time:** 2024-01-06 10:30:00 UTC
```

## Performance Optimizations

### Python Virtual Environment

**Why use venv in Docker:**
- Isolates dependencies from system Python
- Easier to copy in multi-stage build
- Better dependency management
- Prevents conflicts

### Pip Optimizations

**--no-cache-dir flag:**
- Saves ~100MB in image size
- Prevents stale cached packages
- Forces fresh downloads

**--upgrade pip:**
- Gets latest bug fixes
- Improved dependency resolution
- Better error messages

### Model Caching

**Cache directory:**
```dockerfile
RUN mkdir -p /home/appuser/.cache && \
    chown -R appuser:appuser /home/appuser
```

**What gets cached:**
- Downloaded Hugging Face models
- Tokenizer files
- Model configuration
- Preprocessing artifacts

**First run:** Downloads model (~250MB for distilgpt2)
**Subsequent runs:** Uses cached model (instant startup)

## Customization Options

### Using Different Models

**Edit app.py:**
```python
# Lightweight models (< 1GB)
generator = pipeline('text-generation', model='distilgpt2')
generator = pipeline('text-generation', model='gpt2')

# Larger models (2-6GB)
generator = pipeline('text-generation', model='gpt2-medium')
generator = pipeline('text-generation', model='gpt2-large')

# Different tasks
classifier = pipeline('sentiment-analysis', model='distilbert-base-uncased-finetuned-sst-2-english')
summarizer = pipeline('summarization', model='facebook/bart-large-cnn')
```

### Adding Authentication

**Basic auth example:**
```python
from flask import request
from functools import wraps

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.headers.get('Authorization')
        if auth != 'Bearer YOUR_SECRET_TOKEN':
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated

@app.route('/generate', methods=['POST'])
@require_auth
def generate():
    # existing code
```

### Scaling Considerations

**For production deployments:**

1. **Add Gunicorn:** Replace Flask development server
```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
```

2. **Use GPU:** For faster inference
```dockerfile
FROM nvidia/cuda:11.8-cudnn8-runtime-ubuntu22.04
# Add CUDA-enabled PyTorch
```

3. **Add Redis:** For request caching
```python
import redis
r = redis.Redis(host='redis', port=6379)
```

4. **Load balancing:** Deploy multiple containers
```yaml
# docker-compose.yml
services:
  model-runner:
    image: your-image:latest
    deploy:
      replicas: 3
```

## Monitoring and Observability

### Adding Prometheus Metrics

```python
from prometheus_flask_exporter import PrometheusMetrics

metrics = PrometheusMetrics(app)

# Custom metric
inference_time = metrics.histogram(
    'model_inference_duration_seconds',
    'Model inference duration'
)
```

### Structured Logging

```python
import json
import logging

class JsonFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'message': record.getMessage(),
            'module': record.module
        })

handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)
```

## Best Practices Summary

1. **Always test locally before pushing**
2. **Review security scan results**
3. **Monitor build times and cache hit rates**
4. **Keep dependencies up to date**
5. **Use specific version pins in requirements.txt**
6. **Review GitHub Actions logs after each build**
7. **Implement proper error handling**
8. **Add comprehensive logging**
9. **Document configuration changes**
10. **Test with realistic workloads**

## Further Reading

- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Hugging Face Model Hub](https://huggingface.co/models)