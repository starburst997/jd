#!/usr/bin/env bash

# Apply devcontainer template to current project

# Default template
DEFAULT_TEMPLATE="nodejs-postgres"

# Available templates (can be expanded)
declare -A TEMPLATE_MAP=(
    ["nodejs-postgres"]="ghcr.io/starburst997/devcontainer/templates/nodejs-postgres"
)

show_dev_help() {
    cat <<EOF
Apply devcontainer template to current project

Usage: jd dev [TEMPLATE] [OPTIONS]

Templates:
    nodejs-postgres   Node.js with PostgreSQL (default)

    Or use any template name from the default registry:
    ghcr.io/starburst997/devcontainer/templates/<name>

    Or specify a full template ID from any registry

Options:
    --force           Overwrite existing .devcontainer
    --list            List all available templates
    -h, --help        Show this help message

Examples:
    jd dev                                    # Use default nodejs-postgres
    jd dev nodejs                             # Use ghcr.io/starburst997/devcontainer/templates/nodejs
    jd dev python                             # Use ghcr.io/starburst997/devcontainer/templates/python
    jd dev nodejs-postgres --force           # Force overwrite
    jd dev ghcr.io/my/template/custom        # Use custom template ID from another registry
    jd dev devcontainers/templates/go         # Use template with path from another registry

EOF
}

list_templates() {
    info "Available template shortcuts:"
    echo ""
    for key in "${!TEMPLATE_MAP[@]}"; do
        printf "  %-20s %s\n" "$key" "${TEMPLATE_MAP[$key]}"
    done | sort
    echo ""
    info "Default registry: ghcr.io/starburst997/devcontainer/templates/"
    info "Any template name without '/' will use the default registry"
    info "Example: 'jd dev nodejs' → ghcr.io/starburst997/devcontainer/templates/nodejs"
    echo ""
    info "You can also use any full template ID from other registries"
    info "Find more at: https://containers.dev/templates"
}

execute_command() {
    local template="${1:-$DEFAULT_TEMPLATE}"
    local force=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                shift
                ;;
            --list)
                list_templates
                return 0
                ;;
            -h|--help)
                show_dev_help
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                show_dev_help
                return 1
                ;;
            *)
                template="$1"
                shift
                ;;
        esac
    done

    # Check dependencies
    check_command_dependencies "dev" || return 1

    # Check if devcontainer already exists
    if [ -d ".devcontainer" ] && [ "$force" != true ]; then
        error ".devcontainer directory already exists"
        info "Use --force to overwrite"
        return 1
    fi

    # Resolve template ID
    local template_id="$template"
    if [[ -n "${TEMPLATE_MAP[$template]}" ]]; then
        # Template exists in known map
        template_id="${TEMPLATE_MAP[$template]}"
        log "Using template: $template ($template_id)"
    elif [[ "$template" != *"/"* ]]; then
        # No slash means it's a template name, not a full registry path
        # Prepend default registry path
        template_id="ghcr.io/starburst997/devcontainer/templates/$template"
        info "Using template from default registry: $template_id"
    else
        # Contains slash, assume it's a full registry path
        log "Using custom template: $template_id"
    fi

    # Check if we need to use local devcontainer
    local devcontainer_cmd="devcontainer"
    if ! command_exists devcontainer; then
        if [ -f "$JD_CLI_ROOT/node_modules/.bin/devcontainer" ]; then
            devcontainer_cmd="$JD_CLI_ROOT/node_modules/.bin/devcontainer"
        else
            error "devcontainer CLI not found"
            return 1
        fi
    fi

    # Remove existing .devcontainer if force is set
    if [ "$force" = true ] && [ -d ".devcontainer" ]; then
        warning "Removing existing .devcontainer directory"
        rm -rf .devcontainer
    fi

    # Apply template
    info "Applying devcontainer template..."
    debug "Running: $devcontainer_cmd templates apply --template-id \"$template_id\" --workspace-folder ."

    if $devcontainer_cmd templates apply \
        --template-id "$template_id" \
        --workspace-folder .; then
        log "Successfully applied devcontainer template"

        # Get git repository name for deterministic naming
        local repo_name=""
        if git rev-parse --is-inside-work-tree &>/dev/null; then
            # Try to get repo name from remote origin
            local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
            if [ -n "$remote_url" ]; then
                # Extract repo name from URL (works with both HTTPS and SSH)
                repo_name=$(basename -s .git "$remote_url")
                debug "Detected repository name: $repo_name"
            else
                # Fallback to directory name if no remote
                repo_name=$(basename "$(pwd)")
                debug "No remote found, using directory name: $repo_name"
            fi
        else
            # Not in a git repo, use directory name
            repo_name=$(basename "$(pwd)")
            debug "Not in git repo, using directory name: $repo_name"
        fi

        # Replace workspace folder placeholders with repository name
        if [ -n "$repo_name" ]; then
            # Update devcontainer.json if it exists
            if [ -f ".devcontainer/devcontainer.json" ]; then
                debug "Updating devcontainer.json with repository name"
                # Use sed to replace the name field
                if grep -q '"name".*${localWorkspaceFolderBasename}' ".devcontainer/devcontainer.json"; then
                    sed -i.bak "s/\"name\": \"\${localWorkspaceFolderBasename}\"/\"name\": \"$repo_name\"/" ".devcontainer/devcontainer.json"
                    rm -f ".devcontainer/devcontainer.json.bak"
                    info "Updated devcontainer.json with repository name: $repo_name"
                fi
            fi

            # Update docker-compose.yml if it exists
            if [ -f ".devcontainer/docker-compose.yml" ]; then
                debug "Updating docker-compose.yml with repository name"
                # Use sed to replace the name field in docker-compose
                if grep -q 'name:.*${localWorkspaceFolderBasename}' ".devcontainer/docker-compose.yml"; then
                    sed -i.bak "s/name: \${localWorkspaceFolderBasename}/name: $repo_name/" ".devcontainer/docker-compose.yml"
                    rm -f ".devcontainer/docker-compose.yml.bak"
                    info "Updated docker-compose.yml with repository name: $repo_name"
                fi
            fi
        fi

        # Check if VS Code is installed and offer to open
        if command_exists code; then
            if confirm "Open in VS Code with Dev Container?" "y"; then
                code . --command "remote-containers.openFolder"
            fi
        fi
    else
        error "Failed to apply devcontainer template"
        return 1
    fi
}