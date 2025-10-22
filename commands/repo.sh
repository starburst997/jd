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
    --claude              Also add CLAUDE_CODE_OAUTH_TOKEN secret
    --apple               Also add Apple App Store and Fastlane secrets
    --suffix SUFFIX       Add suffix to APPSTORE and MATCH_ secrets (use with --apple)
    --public              Create public repository (default: private)
    --description DESC    Repository description
    --no-init             Skip git initialization (use existing repo)
    -h, --help           Show this help message

Examples:
    jd repo                                    # Initialize private repo with bot secrets
    jd repo --npm                              # Add NPM_TOKEN as well
    jd repo --extensions                       # Add VSCE_PAT and OVSX_PAT as well
    jd repo --claude                           # Add CLAUDE_CODE_OAUTH_TOKEN as well
    jd repo --apple                            # Add Apple, Fastlane, and GH_PAT secrets
    jd repo --apple --suffix DEV               # Add Apple secrets with _DEV suffix
    jd repo --npm --extensions --claude        # Add all secrets
    jd repo --public --description "My awesome project"

Secret References:
    BOT_ID:                   op://dev/github-app/BOT_ID
    BOT_KEY:                  op://dev/github-app/BOT_KEY
    NPM_TOKEN:                op://dev/npm/NPM_TOKEN
    VSCE_PAT:                 op://dev/extensions/VSCE_PAT
    OVSX_PAT:                 op://dev/extensions/OVSX_PAT
    CLAUDE_CODE_OAUTH_TOKEN:  op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN
    APPSTORE_ISSUER_ID:       op://dev/apple/APPSTORE_ISSUER_ID (or APPSTORE_ISSUER_ID_<SUFFIX>)
    APPSTORE_KEY_ID:          op://dev/apple/APPSTORE_KEY_ID (or APPSTORE_KEY_ID_<SUFFIX>)
    APPSTORE_P8:              op://dev/apple/APPSTORE_P8 (or APPSTORE_P8_<SUFFIX>)
    MATCH_REPOSITORY:         op://dev/fastlane/MATCH_REPOSITORY (or MATCH_REPOSITORY_<SUFFIX>)
    MATCH_PASSWORD:           op://dev/fastlane/MATCH_PASSWORD (or MATCH_PASSWORD_<SUFFIX>)
    GH_PAT:                   op://dev/github/GH_PAT

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
    local add_claude=false
    local add_apple=false
    local suffix=""
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
            --claude)
                add_claude=true
                shift
                ;;
            --apple)
                add_apple=true
                shift
                ;;
            --suffix)
                suffix="$2"
                shift 2
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

    # Add Claude Code OAuth token if requested
    if [ "$add_claude" = true ]; then
        add_secret "CLAUDE_CODE_OAUTH_TOKEN" "op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN" || return 1
    fi

    # Add Apple and Fastlane secrets if requested
    if [ "$add_apple" = true ]; then
        # Determine suffix for secret names and 1Password references
        local secret_suffix=""
        if [ -n "$suffix" ]; then
            secret_suffix="_${suffix}"
        fi

        add_secret "APPSTORE_ISSUER_ID${secret_suffix}" "op://dev/apple/APPSTORE_ISSUER_ID${secret_suffix}" || return 1
        add_secret "APPSTORE_KEY_ID${secret_suffix}" "op://dev/apple/APPSTORE_KEY_ID${secret_suffix}" || return 1
        add_secret "APPSTORE_P8${secret_suffix}" "op://dev/apple/APPSTORE_P8${secret_suffix}" || return 1
        add_secret "MATCH_REPOSITORY${secret_suffix}" "op://dev/fastlane/MATCH_REPOSITORY${secret_suffix}" || return 1
        add_secret "MATCH_PASSWORD${secret_suffix}" "op://dev/fastlane/MATCH_PASSWORD${secret_suffix}" || return 1
        add_secret "GH_PAT" "op://dev/github/GH_PAT" || return 1
    fi

    log "Repository initialization complete!"

    # Show repository URL
    local repo_url=$(gh repo view --json url -q .url 2>/dev/null)
    [ -n "$repo_url" ] && info "Repository URL: $repo_url"
}
