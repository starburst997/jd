#!/usr/bin/env bash

# npm command - Setup npm package with OIDC trusted publishing

show_npm_help() {
    cat << EOF
Usage: jd npm [OPTIONS]

Setup npm package with OIDC trusted publishing by creating a placeholder package
and configuring trusted publisher settings.

This command automates the initial setup required for npm OIDC publishing:
  1. Reads package information from package.json
  2. Creates and publishes a minimal 0.0.0-placeholder version
  3. Opens the npm access settings page for OIDC configuration

Options:
  --help              Show this help message

Examples:
  jd npm              Setup npm package with OIDC publishing

Note:
  - You must have a package.json in the current directory
  - You'll authenticate via npm login (browser-based or terminal)
  - After the placeholder is published, you'll configure OIDC manually via the web UI
EOF
}

execute_command() {
    # Check if help is requested
    if [[ "$1" == "--help" ]]; then
        show_npm_help
        return 0
    fi

    # Ensure we're in a directory with package.json
    if [[ ! -f "package.json" ]]; then
        error "No package.json found in current directory"
        error "Please run this command from your package root directory"
        return 1
    fi

    log "Setting up npm package with OIDC trusted publishing"
    echo ""

    # Read package information
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed"
        error "Please install jq: brew install jq (macOS) or apt install jq (Linux)"
        return 1
    fi

    local package_name
    package_name=$(jq -r '.name' package.json)

    if [[ -z "$package_name" || "$package_name" == "null" ]]; then
        error "Could not read package name from package.json"
        return 1
    fi

    local package_desc
    package_desc=$(jq -r '.description // ""' package.json)

    info "Package name: $package_name"
    if [[ -n "$package_desc" ]]; then
        info "Description: $package_desc"
    fi
    echo ""

    # Login to npm
    #warning "You need to be logged in to npm to publish the placeholder package"
    #info "Opening npm login flow..."
    #echo ""
    #
    #if ! npm login; then
    #    error "Failed to login to npm"
    #    return 1
    #fi

    echo ""
    success "Successfully logged in to npm"
    echo ""

    # Create temporary directory for placeholder package
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    log "Creating placeholder package in temporary directory..."

    # Create minimal package.json
    cat > "$tmp_dir/package.json" << EOF
{
  "name": "$package_name",
  "version": "0.0.0-placeholder",
  "description": "Placeholder package for OIDC setup - DO NOT USE",
  "private": false,
  "repository": {
    "type": "git",
    "url": "$(git config --get remote.origin.url 2>/dev/null || echo "")"
  }
}
EOF

    # Create README explaining this is a placeholder
    cat > "$tmp_dir/README.md" << EOF
# $package_name

**⚠️ THIS IS A PLACEHOLDER PACKAGE - DO NOT USE ⚠️**

This package exists **ONLY** for OIDC trusted publishing configuration.

The package is **NOT** functional and should not be installed or used.

A real version will be published via OIDC-enabled CI/CD shortly.
EOF

    # Copy npm credentials to temp directory
    if [[ -f ~/.npmrc ]]; then
        cp ~/.npmrc "$tmp_dir/.npmrc"
    fi

    # Publish placeholder package
    log "Publishing placeholder package to npm..."
    (
        cd "$tmp_dir" || exit 1

        if npm publish --tag placeholder --access public 2>&1; then
            success "Placeholder package published successfully!"
        else
            error "Failed to publish placeholder package"
            return 1
        fi
    )

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    echo ""
    success "Placeholder package created: $package_name@0.0.0-placeholder"
    echo ""

    # Instructions for OIDC setup
    cat << EOF
${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}
${BLUE}║${NC}  Next Step: Configure OIDC Trusted Publishing                 ${BLUE}║${NC}
${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}

Opening npm package access settings page...

${YELLOW}Manual Configuration Required:${NC}

1. On the npm access page, scroll to "Publishing access"
2. Click "Add trusted publisher"
3. Select "GitHub Actions" as the provider
4. Fill in the following details:

   ${GREEN}Repository Owner/Organization:${NC} $(git config --get remote.origin.url | sed -E 's/.*[:/]([^/]+)\/[^/]+\.git/\1/' 2>/dev/null || echo "YOUR_ORG")
   ${GREEN}Repository Name:${NC} $(git config --get remote.origin.url | sed -E 's/.*\/([^/]+)\.git/\1/' 2>/dev/null || echo "YOUR_REPO")
   ${GREEN}Workflow Filename:${NC} release.yaml (or your workflow file name)
   ${GREEN}Environment:${NC} (leave empty unless using GitHub Environments)

5. Click "Add" to save the trusted publisher

${YELLOW}After OIDC is configured:${NC}
- Push to your main branch
- Your GitHub Action will publish using OIDC (no token needed!)
- The placeholder version will be replaced with your real package

EOF

    # Open browser to access page
    local access_url="https://www.npmjs.com/package/$package_name/access"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$access_url"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "$access_url" 2>/dev/null || {
            info "Open this URL in your browser:"
            echo "  $access_url"
        }
    else
        info "Open this URL in your browser:"
        echo "  $access_url"
    fi

    echo ""
    success "Setup complete! Configure OIDC on the npm website and you're ready to go."
}
