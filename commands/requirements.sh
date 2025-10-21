#!/usr/bin/env bash

show_requirements_help() {
    cat <<EOF
Generate requirements.txt file

Usage: jd requirements [OPTIONS]

Description:
    Generates requirements.txt using pip freeze from the active virtual environment.

Options:
    -h, --help        Show this help message

Examples:
    jd requirements      # Generate requirements.txt
EOF
}

execute_command() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_requirements_help
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                show_requirements_help
                return 1
                ;;
            *)
                error "Unknown argument: $1"
                show_requirements_help
                return 1
                ;;
        esac
    done

    if [ ! -d "venv" ]; then
        error "Virtual environment not found. Run 'jd venv' first."
        return 1
    fi

    info "Generating requirements.txt..."
    if venv/bin/pip freeze > requirements.txt; then
        log "requirements.txt generated successfully"
    else
        error "Failed to generate requirements.txt"
        return 1
    fi
}
