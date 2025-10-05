#!/usr/bin/env bash

# Dependency checker for jd CLI

# Check and prompt for required dependencies
check_dependency() {
    local cmd="$1"
    local name="${2:-$cmd}"
    local install_cmd="$3"
    local is_optional="${4:-false}"

    if command_exists "$cmd"; then
        debug "$name is installed"
        return 0
    fi

    if [ "$is_optional" = true ]; then
        warning "$name is not installed (optional)"
        if [ -n "$install_cmd" ]; then
            info "To install: $install_cmd"
        fi
        return 0
    fi

    error "$name is not installed"

    if [ -n "$install_cmd" ]; then
        echo ""
        warning "$name is required but not installed"

        if confirm "Would you like to install $name automatically?" "y"; then
            info "Installing $name..."
            eval "$install_cmd"
            if [ $? -eq 0 ]; then
                log "$name installed successfully"
                return 0
            else
                error "Failed to install $name"
                echo "Please install manually: $install_cmd"
                return 1
            fi
        else
            echo "To install manually, run:"
            echo "  $install_cmd"
            return 1
        fi
    fi

    return 1
}

# Check GitHub CLI
check_gh_cli() {
    local os=$(get_os)
    local install_cmd=""

    case "$os" in
        macos)
            install_cmd="brew install gh"
            ;;
        linux)
            if command_exists apt-get; then
                install_cmd="curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt update && sudo apt install gh"
            elif command_exists yum; then
                install_cmd="sudo yum install gh"
            else
                install_cmd="Visit https://github.com/cli/cli#installation"
            fi
            ;;
        windows)
            install_cmd="winget install --id GitHub.cli or scoop install gh"
            ;;
        *)
            install_cmd="Visit https://github.com/cli/cli#installation"
            ;;
    esac

    if ! check_dependency "gh" "GitHub CLI" "$install_cmd"; then
        return 1
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        warning "GitHub CLI is not authenticated"

        if confirm "Would you like to authenticate with GitHub now?" "y"; then
            info "Starting GitHub authentication..."
            echo ""
            echo "You'll be guided through the GitHub login process."
            echo "Choose your preferred authentication method when prompted."
            echo ""

            if gh auth login; then
                log "Successfully authenticated with GitHub"
            else
                error "GitHub authentication failed"
                echo "Please run manually: gh auth login"
                return 1
            fi
        else
            echo "To authenticate manually, run:"
            echo "  gh auth login"
            return 1
        fi
    fi

    return 0
}

# Check devcontainer CLI
check_devcontainer_cli() {
    if command_exists devcontainer; then
        debug "devcontainer CLI is installed globally"
        return 0
    fi

    # Check if installed via npm package dependency
    local devcontainer_path="$JD_CLI_ROOT/node_modules/.bin/devcontainer"
    if [ -f "$devcontainer_path" ]; then
        # Export path for subshells
        export PATH="$JD_CLI_ROOT/node_modules/.bin:$PATH"
        debug "Using local devcontainer CLI from node_modules"
        return 0
    fi

    warning "devcontainer CLI is not available"

    if confirm "Would you like to install devcontainer CLI now?" "y"; then
        info "Installing @devcontainers/cli..."

        # Try global install first (preferred)
        if npm install -g @devcontainers/cli; then
            log "devcontainer CLI installed successfully"
            return 0
        else
            warning "Global install failed, trying local install..."

            # Fall back to local install in jd CLI directory
            cd "$JD_CLI_ROOT"
            if npm install @devcontainers/cli; then
                export PATH="$JD_CLI_ROOT/node_modules/.bin:$PATH"
                log "devcontainer CLI installed locally"
                return 0
            else
                error "Failed to install devcontainer CLI"
                echo "Please install manually: npm install -g @devcontainers/cli"
                return 1
            fi
        fi
    else
        echo "To install manually, run:"
        echo "  npm install -g @devcontainers/cli"
        return 1
    fi
}

# Check Node.js and npm
check_nodejs() {
    local node_min_version="14.0.0"
    local npm_min_version="6.0.0"

    if ! command_exists node; then
        error "Node.js is not installed"
        info "Visit https://nodejs.org/ to install Node.js"
        return 1
    fi

    if ! command_exists npm; then
        error "npm is not installed"
        info "npm usually comes with Node.js"
        return 1
    fi

    # Check versions
    local node_version=$(node --version | sed 's/v//')
    local npm_version=$(npm --version)

    debug "Node.js version: $node_version"
    debug "npm version: $npm_version"

    return 0
}

# Check all dependencies for a specific command
check_command_dependencies() {
    local cmd="$1"
    local auto_install="${2:-false}"

    # Set auto-install mode if requested
    if [ "$auto_install" = true ]; then
        export JD_AUTO_INSTALL=true
    fi

    case "$cmd" in
        pr)
            check_gh_cli || return 1
            ;;
        dev)
            check_devcontainer_cli || return 1
            ;;
        *)
            # No specific dependencies
            ;;
    esac

    # Unset auto-install mode
    unset JD_AUTO_INSTALL

    return 0
}

# Install all missing dependencies
install_all_dependencies() {
    info "Checking and installing all dependencies..."
    echo ""

    local failed=false

    # Check Node.js first (required for everything)
    if ! check_nodejs; then
        error "Node.js is required. Please install from https://nodejs.org/"
        failed=true
    fi

    # Install devcontainer CLI
    echo ""
    info "Checking devcontainer CLI..."
    if ! check_devcontainer_cli; then
        warning "Could not install devcontainer CLI"
        failed=true
    fi

    # Install and configure GitHub CLI
    echo ""
    info "Checking GitHub CLI..."
    if ! check_gh_cli; then
        warning "Could not install/configure GitHub CLI"
        failed=true
    fi

    echo ""
    if [ "$failed" = true ]; then
        warning "Some dependencies could not be installed automatically"
        echo "Please install them manually as shown above"
        return 1
    else
        log "All dependencies installed successfully!"
        return 0
    fi
}