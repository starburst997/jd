#!/usr/bin/env bash

# Post-install script to check system dependencies
# This runs after npm install to verify required tools

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source utilities
source "$ROOT_DIR/utils/common.sh"

echo ""
log "Checking system dependencies for jd CLI..."
echo ""

# Track if any required dependencies are missing
MISSING_REQUIRED=false

# Check for Git (required)
if command_exists git; then
    info "✓ Git is installed ($(git --version))"
else
    error "✗ Git is not installed (required)"
    MISSING_REQUIRED=true
fi

# Check for GitHub CLI (optional but recommended)
if command_exists gh; then
    info "✓ GitHub CLI is installed ($(gh --version | head -1))"

    # Check authentication
    if gh auth status &>/dev/null; then
        info "  ✓ GitHub CLI is authenticated"
    else
        warning "  ⚠ GitHub CLI is not authenticated"
        echo "    To authenticate: gh auth login"
    fi
else
    warning "⚠ GitHub CLI is not installed (optional)"
    echo "  Required for 'jd pr' and 'jd repo' commands"
    echo "  To install: https://cli.github.com/"
fi

# Check for 1Password CLI (optional)
if command_exists op; then
    info "✓ 1Password CLI is installed ($(op --version))"
else
    warning "⚠ 1Password CLI is not installed (optional)"
    echo "  Required for 'jd repo' command"
    echo "  To install: https://developer.1password.com/docs/cli/get-started/"
fi

# Check for Docker (optional)
if command_exists docker; then
    info "✓ Docker is installed ($(docker --version))"
else
    warning "⚠ Docker is not installed (optional)"
    echo "  Recommended for using dev containers"
    echo "  To install: https://docs.docker.com/get-docker/"
fi

# Check for VS Code (optional)
if command_exists code; then
    info "✓ VS Code is installed"
else
    echo "⚠ VS Code is not installed (optional)"
    echo "  Recommended for dev container integration"
fi

echo ""

if [ "$MISSING_REQUIRED" = true ]; then
    error "Some required dependencies are missing"
    echo "Please install them before using jd CLI"
    exit 1
else
    log "All required dependencies are installed!"
    echo ""
    echo "To get started:"
    echo "  jd --help        Show available commands"
    echo "  jd dev           Apply devcontainer template"
    echo "  jd pr            Create GitHub pull request"
    echo "  jd repo          Initialize GitHub repository with secrets"
fi

echo ""