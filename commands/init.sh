#!/usr/bin/env bash

# Setup jd CLI and install CLI tool dependencies

show_init_help() {
    cat <<EOF
Setup jd CLI and install CLI tool dependencies

This is an optional first-time setup command that helps install the CLI tools
needed by jd commands.

Usage: jd init [OPTIONS]

Options:
    --skip-deps          Skip dependency installation
    --skip-completions   Skip shell completion setup
    --force              Force reinstall all dependencies
    -h, --help           Show this help message

This command will:
    1. Check system requirements (Node.js, npm)
    2. Install missing CLI tools (GitHub CLI, devcontainer CLI)
    3. Configure GitHub authentication
    4. Setup shell completions for tab completion
    5. Verify everything is working

Examples:
    jd init                       # Full setup with prompts
    jd init --skip-deps           # Skip dependency checks
    jd init --skip-completions    # Skip shell completion setup
    jd init --force               # Reinstall everything

EOF
}

# Setup shell completion for the current shell
setup_shell_completion() {
    local shell_name=""
    local rc_file=""
    local completion_line=""

    # Detect user's shell (not the script's shell)
    # Since this script runs in bash (shebang), we need to check $SHELL env var first
    # to detect the user's actual shell, not the script interpreter
    case "$SHELL" in
        */bash)
            shell_name="bash"
            # Check common bash rc files
            if [ -f "$HOME/.bashrc" ]; then
                rc_file="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                rc_file="$HOME/.bash_profile"
            else
                rc_file="$HOME/.bashrc"
            fi
            completion_line='eval "$(jd completion bash)"'
            ;;
        */zsh)
            shell_name="zsh"
            rc_file="$HOME/.zshrc"
            completion_line='eval "$(jd completion zsh)"'
            ;;
        *)
            # Fallback: try to detect from version variables (if run directly in a shell)
            if [ -n "$ZSH_VERSION" ]; then
                shell_name="zsh"
                rc_file="$HOME/.zshrc"
                completion_line='eval "$(jd completion zsh)"'
            elif [ -n "$BASH_VERSION" ]; then
                shell_name="bash"
                if [ -f "$HOME/.bashrc" ]; then
                    rc_file="$HOME/.bashrc"
                elif [ -f "$HOME/.bash_profile" ]; then
                    rc_file="$HOME/.bash_profile"
                else
                    rc_file="$HOME/.bashrc"
                fi
                completion_line='eval "$(jd completion bash)"'
            else
                warning "Could not detect shell type from SHELL=$SHELL"
                return 1
            fi
            ;;
    esac

    info "Setting up $shell_name completion..."

    # Check if completion is already configured
    if [ -f "$rc_file" ] && grep -qF "jd completion $shell_name" "$rc_file"; then
        success "Shell completion already configured in $rc_file"
        return 0
    fi

    # Ask user for permission
    echo "  This will add the following line to $rc_file:"
    echo "  $completion_line"
    echo ""

    if confirm "Add shell completion to $rc_file?" "y"; then
        # Backup rc file
        cp "$rc_file" "${rc_file}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

        # Add completion line
        echo "" >> "$rc_file"
        echo "# jd CLI completion" >> "$rc_file"
        echo "$completion_line" >> "$rc_file"

        success "Shell completion added to $rc_file"

        # Provide instructions to activate in current shell
        # We can't source the file directly because this script runs in a subprocess
        echo ""
        info "To activate completions in your current shell, run:"
        echo "  source $rc_file"
        echo ""
        echo "Or simply start a new shell session."

        return 0
    else
        info "Skipping shell completion setup"
        echo "  You can set it up manually later with:"
        echo "  echo '$completion_line' >> $rc_file"
        return 0
    fi
}

execute_command() {
    local skip_deps=false
    local skip_completions=false
    local force=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-completions)
                skip_completions=true
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
        echo "  • mac-cleanup - Required for 'jd cleanup' command (macOS only)"
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

    # Setup shell completions
    if [ "$skip_completions" != true ]; then
        echo ""
        setup_shell_completion || warning "Shell completion setup failed (continuing anyway)"
    fi

    echo ""
    log "jd CLI setup complete!"
    echo ""
    echo "All CLI dependencies are ready. You can now use jd commands:"
    echo "  jd dev [template]    - Apply devcontainer template"
    echo "  jd pr [options]      - Create GitHub pull request"
    echo "  jd repo [options]    - Initialize GitHub repository"
    echo "  jd cleanup [path]    - Clean up node_modules and free disk space"
    echo "  jd completion        - Setup shell completions"
    echo "  jd update            - Update jd CLI to latest version"
    echo "  jd --help            - Show all commands"
    echo ""
    info "Get started with: jd --help"
}