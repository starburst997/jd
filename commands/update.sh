#!/usr/bin/env bash

# Update jd CLI to the latest version

show_update_help() {
    cat <<EOF
Update jd CLI to the latest version

Usage: jd update [OPTIONS]

Options:
    --check           Check for updates without installing
    --force           Force update even if already on latest
    --channel CHAN    Update channel (stable, beta, dev)
    -h, --help        Show this help message

Examples:
    jd update                # Update to latest stable
    jd update --check        # Check if updates available
    jd update --force        # Force reinstall
    jd update --channel beta # Install beta version

EOF
}

check_for_updates() {
    local current_version="${JD_CLI_VERSION:-unknown}"
    local latest_version

    info "Checking for updates..."
    info "Current version: $current_version"

    # Get latest version from npm
    latest_version=$(npm view @jdboivin/jd-cli version 2>/dev/null || echo "")

    if [ -z "$latest_version" ]; then
        # Package might not be published yet, check GitHub releases
        if command_exists gh; then
            latest_version=$(gh release list --repo jdboivin/jd-cli --limit 1 2>/dev/null | awk '{print $1}' | sed 's/^v//')
        fi
    fi

    if [ -z "$latest_version" ]; then
        warning "Could not determine latest version"
        return 2
    fi

    info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log "You are on the latest version"
        return 1
    else
        log "Update available: $current_version → $latest_version"
        return 0
    fi
}

execute_command() {
    local check_only=false
    local force=false
    local channel="stable"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                check_only=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --channel)
                channel="$2"
                shift 2
                ;;
            -h|--help)
                show_update_help
                return 0
                ;;
            *)
                error "Unknown option: $1"
                show_update_help
                return 1
                ;;
        esac
    done

    # Check for updates
    check_for_updates
    local update_status=$?

    if [ "$check_only" = true ]; then
        return 0
    fi

    # If no update available and not forcing
    if [ $update_status -eq 1 ] && [ "$force" != true ]; then
        info "No update needed"
        return 0
    fi

    # Determine update method based on installation
    local install_method=""

    # Check if installed via npm globally
    if npm list -g @jdboivin/jd-cli &>/dev/null; then
        install_method="npm"
    # Check if installed via homebrew
    elif command_exists brew && brew list jd-cli &>/dev/null; then
        install_method="brew"
    # Check if running from source
    elif [ -f "$JD_CLI_ROOT/package.json" ]; then
        install_method="source"
    else
        install_method="unknown"
    fi

    info "Installation method: $install_method"

    case "$install_method" in
        npm)
            if confirm "Update jd CLI via npm?" "y"; then
                info "Updating via npm..."

                local package_name="@jdboivin/jd-cli"
                if [ "$channel" != "stable" ]; then
                    package_name="@jdboivin/jd-cli@$channel"
                fi

                if npm update -g "$package_name"; then
                    log "Successfully updated jd CLI"

                    # Run post-install to check dependencies
                    info "Checking dependencies..."
                    jd init --skip-deps
                else
                    error "Failed to update via npm"
                    return 1
                fi
            fi
            ;;

        brew)
            if confirm "Update jd CLI via Homebrew?" "y"; then
                info "Updating via Homebrew..."

                if brew upgrade jd-cli; then
                    log "Successfully updated jd CLI"
                else
                    error "Failed to update via Homebrew"
                    return 1
                fi
            fi
            ;;

        source)
            if confirm "Update from source?" "y"; then
                info "Updating from source..."

                cd "$JD_CLI_ROOT"

                # Stash any local changes
                if ! git diff-index --quiet HEAD --; then
                    warning "You have local changes"
                    if confirm "Stash local changes?" "y"; then
                        git stash
                    fi
                fi

                # Pull latest changes
                if git pull origin main; then
                    # Install dependencies
                    npm install

                    log "Successfully updated from source"
                    info "You may need to restart your terminal"
                else
                    error "Failed to update from source"
                    return 1
                fi
            fi
            ;;

        *)
            error "Cannot determine installation method"
            echo ""
            echo "Please update manually:"
            echo "  • If installed via npm: npm update -g @jdboivin/jd-cli"
            echo "  • If installed via brew: brew upgrade jd-cli"
            echo "  • If from source: cd to jd-cli directory and run: git pull && npm install"
            return 1
            ;;
    esac

    echo ""
    log "Update complete!"

    # Show version
    jd --version
}