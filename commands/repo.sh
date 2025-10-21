#!/usr/bin/env bash

# Initialize GitHub repository and configure secrets

show_repo_help() {
    cat <<EOF
Initialize GitHub repository and configure secrets

Usage: jd repo [OPTIONS]

Description:
    Initializes a GitHub repository for the current directory and adds
    secrets using the 1Password CLI (op) and GitHub CLI (gh).

    Always adds:
    - BOT_ID (from op://dev/github-app/BOT_ID)
    - BOT_KEY (from op://dev/github-app/BOT_KEY)

Options:
    --npm                 Also add NPM_TOKEN secret
    --extensions          Also add VSCE_PAT and OVSX_PAT secrets
    --public              Create public repository (default: private)
    --description DESC    Repository description
    --no-init             Skip git initialization (use existing repo)
    -h, --help           Show this help message

Examples:
    jd repo                              # Initialize private repo with bot secrets
    jd repo --npm                        # Add NPM_TOKEN as well
    jd repo --extensions                 # Add VSCE_PAT and OVSX_PAT as well
    jd repo --npm --extensions           # Add all secrets
    jd repo --public --description "My awesome project"

Secret References:
    BOT_ID:     op://dev/github-app/BOT_ID
    BOT_KEY:    op://dev/github-app/BOT_KEY
    NPM_TOKEN:  op://dev/npm/NPM_TOKEN
    VSCE_PAT:   op://dev/extensions/VSCE_PAT
    OVSX_PAT:   op://dev/extensions/OVSX_PAT

EOF
}

# Add a secret to the GitHub repository using op and gh
add_secret() {
    local secret_name="$1"
    local op_reference="$2"

    info "Adding secret: $secret_name"

    # Get secret value from 1Password
    local secret_value
    if ! secret_value=$(op read "$op_reference" 2>/dev/null); then
        error "Failed to read $secret_name from 1Password: $op_reference"
        return 1
    fi

    # Add secret to GitHub repository
    if echo "$secret_value" | gh secret set "$secret_name" 2>/dev/null; then
        log "✓ Added $secret_name"
    else
        error "Failed to add $secret_name to GitHub repository"
        return 1
    fi
}

execute_command() {
    # Check dependencies
    check_command_dependencies "repo" || return 1

    # Default values
    local add_npm=false
    local add_extensions=false
    local visibility="private"
    local description=""
    local skip_init=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --npm)
                add_npm=true
                shift
                ;;
            --extensions)
                add_extensions=true
                shift
                ;;
            --public)
                visibility="public"
                shift
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            --no-init)
                skip_init=true
                shift
                ;;
            -h|--help)
                show_repo_help
                return 0
                ;;
            *)
                error "Unknown option: $1"
                show_repo_help
                return 1
                ;;
        esac
    done

    # Check if already in a git repository
    if [ "$skip_init" = false ]; then
        if git rev-parse --git-dir > /dev/null 2>&1; then
            warning "Already in a git repository"
            #if ! confirm "Continue with existing repository?" "y"; then
            #    return 1
            #fi
        else
            # Initialize git repository
            info "Initializing git repository..."
            if ! git init; then
                error "Failed to initialize git repository"
                return 1
            fi
            log "Git repository initialized"
        fi
    fi

    # Get repository name from current directory
    local repo_name=$(basename "$(pwd)")

    # Check if GitHub repository already exists
    if gh repo view &>/dev/null; then
        warning "GitHub repository already exists"
        info "Repository: $(gh repo view --json nameWithOwner -q .nameWithOwner)"
    else
        # Create GitHub repository
        info "Creating GitHub repository: $repo_name"
        local gh_cmd="gh repo create \"$repo_name\" --source=. --$visibility"
        [ -n "$description" ] && gh_cmd+=" --description \"$description\""

        if eval "$gh_cmd"; then
            log "GitHub repository created successfully"
        else
            error "Failed to create GitHub repository"
            return 1
        fi
    fi

    # Add secrets
    info "Adding secrets to GitHub repository..."

    # Always add bot secrets
    add_secret "BOT_ID" "op://dev/github-app/BOT_ID" || return 1
    add_secret "BOT_KEY" "op://dev/github-app/BOT_KEY" || return 1

    # Add NPM token if requested
    if [ "$add_npm" = true ]; then
        add_secret "NPM_TOKEN" "op://dev/npm/NPM_TOKEN" || return 1
    fi

    # Add extension secrets if requested
    if [ "$add_extensions" = true ]; then
        add_secret "VSCE_PAT" "op://dev/extensions/VSCE_PAT" || return 1
        add_secret "OVSX_PAT" "op://dev/extensions/OVSX_PAT" || return 1
    fi

    log "Repository initialization complete!"

    # Show repository URL
    local repo_url=$(gh repo view --json url -q .url 2>/dev/null)
    [ -n "$repo_url" ] && info "Repository URL: $repo_url"
}
