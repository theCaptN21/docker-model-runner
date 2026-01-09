#!/bin/bash
# Local linting script - run this before pushing to GitHub

set -e  # Exit on first error

echo "=========================================="
echo "Running Local Linting Checks"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in virtual environment
if [[ -z "${VIRTUAL_ENV}" ]]; then
    echo -e "${YELLOW}Warning: Not running in a virtual environment${NC}"
    echo "Consider creating one with: python -m venv venv && source venv/bin/activate"
    echo ""
fi

# Install linting tools if not present
echo "Checking for linting tools..."
pip install -q black isort flake8 pylint 2>/dev/null || true

# Track overall status
FAILED=0

# 1. Black formatter check
echo "=========================================="
echo "1. Running Black formatter check..."
echo "=========================================="
if black --check --diff app.py; then
    echo -e "${GREEN}✓ Black check passed${NC}"
else
    echo -e "${RED}✗ Black check failed${NC}"
    echo ""
    echo "To fix, run: black app.py"
    FAILED=1
fi
echo ""

# 2. isort import check
echo "=========================================="
echo "2. Running isort import check..."
echo "=========================================="
if isort --check-only --diff app.py; then
    echo -e "${GREEN}✓ isort check passed${NC}"
else
    echo -e "${RED}✗ isort check failed${NC}"
    echo ""
    echo "To fix, run: isort app.py"
    FAILED=1
fi
echo ""

# 3. Flake8 linter
echo "=========================================="
echo "3. Running Flake8 linter..."
echo "=========================================="
if flake8 app.py --max-line-length=100 --ignore=E203,W503; then
    echo -e "${GREEN}✓ Flake8 check passed${NC}"
else
    echo -e "${RED}✗ Flake8 check failed${NC}"
    echo ""
    echo "Fix the issues shown above"
    FAILED=1
fi
echo ""

# 4. Hadolint Dockerfile check (if hadolint is installed)
echo "=========================================="
echo "4. Running Hadolint Dockerfile check..."
echo "=========================================="
if command -v hadolint &> /dev/null; then
    if hadolint Dockerfile --failure-threshold warning; then
        echo -e "${GREEN}✓ Hadolint check passed${NC}"
    else
        echo -e "${YELLOW}⚠ Hadolint warnings found (not blocking)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Hadolint not installed, skipping...${NC}"
    echo "Install: brew install hadolint (macOS) or see https://github.com/hadolint/hadolint"
fi
echo ""

# 5. Optional: Pylint (more strict)
echo "=========================================="
echo "5. Running Pylint (optional strict check)..."
echo "=========================================="
if pylint app.py --disable=C0103,C0114,C0115,C0116 --max-line-length=100 2>/dev/null; then
    echo -e "${GREEN}✓ Pylint check passed${NC}"
else
    echo -e "${YELLOW}⚠ Pylint warnings (informational only)${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Safe to commit.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please fix issues before committing.${NC}"
    echo ""
    echo "Quick fix commands:"
    echo "  black app.py      # Auto-format code"
    echo "  isort app.py      # Auto-sort imports"
    exit 1
fi