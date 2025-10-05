#!/usr/bin/env bash

# Initialize jd CLI and install all dependencies

show_init_help() {
    cat <<EOF
Initialize jd CLI and install all dependencies

Usage: jd init [OPTIONS]

Options:
    --skip-deps       Skip dependency installation
    --force           Force reinstall all dependencies
    -h, --help        Show this help message

This command will:
    1. Check system requirements
    2. Install missing dependencies (GitHub CLI, devcontainer CLI)
    3. Configure GitHub authentication
    4. Verify everything is working

Examples:
    jd init                  # Full setup with prompts
    jd init --skip-deps      # Skip dependency checks
    jd init --force          # Reinstall everything

EOF
}

execute_command() {
    local skip_deps=false
    local force=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            -h|--help)
                show_init_help
                return 0
                ;;
            *)
                error "Unknown option: $1"
                show_init_help
                return 1
                ;;
        esac
    done

    log "Initializing jd CLI..."
    echo ""

    # Check Node.js and npm
    info "Checking Node.js and npm..."
    if ! check_nodejs; then
        error "Node.js is required to run jd CLI"
        echo "Please install Node.js from: https://nodejs.org/"
        return 1
    fi
    log "Node.js and npm are installed"
    echo ""

    if [ "$skip_deps" != true ]; then
        # Offer to install all dependencies at once
        info "jd CLI can work with several optional tools:"
        echo "  • GitHub CLI (gh) - Required for 'jd pr' command"
        echo "  • DevContainer CLI - Required for 'jd dev' command"
        echo ""

        if confirm "Would you like to install/configure all dependencies now?" "y"; then
            echo ""
            install_all_dependencies

            if [ $? -ne 0 ]; then
                warning "Some dependencies could not be installed"
                echo "You can still use jd CLI, but some commands may not work"
                echo ""

                if ! confirm "Continue anyway?" "y"; then
                    return 1
                fi
            fi
        else
            info "Skipping dependency installation"
            echo "You can install them later when needed"
        fi
    fi

    echo ""
    log "jd CLI initialization complete!"
    echo ""
    echo "Available commands:"
    echo "  jd dev [template]    - Apply devcontainer template"
    echo "  jd pr [options]      - Create GitHub pull request"
    echo "  jd update            - Update jd CLI to latest version"
    echo "  jd --help            - Show all commands"
    echo ""
    info "Get started with: jd --help"
}