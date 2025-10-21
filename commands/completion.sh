#!/usr/bin/env bash

# Generate shell completion scripts

show_completion_help() {
    cat <<EOF
Generate shell completion scripts for jd CLI

Usage: jd completion SHELL

Supported shells:
    bash    Bash shell completion
    zsh     Zsh shell completion

Setup Instructions:

    Bash:
        Add to your ~/.bashrc or ~/.bash_profile:
        eval "\$(jd completion bash)"

    Zsh:
        Add to your ~/.zshrc:
        eval "\$(jd completion zsh)"

    Automatic Setup:
        Run 'jd init' to automatically configure completions
        for your current shell.

Examples:
    jd completion bash        # Output bash completion script
    jd completion zsh         # Output zsh completion script
    eval "\$(jd completion bash)"  # Load completions in current session

EOF
}

execute_command() {
    local shell="${1:-}"

    # Check for help flag
    if [[ "$shell" == "--help" ]] || [[ "$shell" == "-h" ]] || [[ -z "$shell" ]]; then
        show_completion_help
        exit 0
    fi

    # Output the appropriate completion script
    case "$shell" in
        bash)
            if [ -f "$JD_CLI_ROOT/completions/jd.bash" ]; then
                cat "$JD_CLI_ROOT/completions/jd.bash"
            else
                error "Bash completion script not found at $JD_CLI_ROOT/completions/jd.bash"
                exit 1
            fi
            ;;
        zsh)
            if [ -f "$JD_CLI_ROOT/completions/jd.zsh" ]; then
                cat "$JD_CLI_ROOT/completions/jd.zsh"
            else
                error "Zsh completion script not found at $JD_CLI_ROOT/completions/jd.zsh"
                exit 1
            fi
            ;;
        *)
            error "Unknown shell: $shell"
            echo ""
            echo "Supported shells: bash, zsh"
            echo "Run 'jd completion --help' for usage information"
            exit 1
            ;;
    esac
}
