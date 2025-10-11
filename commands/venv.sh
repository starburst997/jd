#!/usr/bin/env bash

show_venv_help() {
    cat <<EOF
Manage Python virtual environment

Usage: jd venv [OPTIONS]

Description:
    Creates a new Python virtual environment if it doesn't exist.
    Activates the virtual environment if it already exists.

Options:
    -h, --help        Show this help message

Examples:
    jd venv              # Create or activate venv
EOF
}

execute_command() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_venv_help
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                show_venv_help
                return 1
                ;;
            *)
                error "Unknown argument: $1"
                show_venv_help
                return 1
                ;;
        esac
    done

    local python_cmd=""
    if command_exists python3; then
        python_cmd="python3"
    elif command_exists python; then
        python_cmd="python"
    else
        error "python or python3 is not installed"
        return 1
    fi

    if [ -d "venv" ]; then
        info "Virtual environment already exists, activating..."
        echo "source venv/bin/activate"
    else
        info "Creating new virtual environment with $python_cmd..."
        if $python_cmd -m venv venv; then
            log "Virtual environment created successfully"
            echo "source venv/bin/activate"
        else
            error "Failed to create virtual environment"
            return 1
        fi
    fi
}
