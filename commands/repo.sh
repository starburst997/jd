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
    --claude              Also add CLAUDE_CODE_OAUTH_TOKEN secret, copy JD workflows,
                          copy settings.json to .claude/, and create JD label
    --apple               Also add Apple App Store and Fastlane secrets
    --suffix SUFFIX       Add suffix to APPSTORE and MATCH_ secrets (use with --apple)
    --rules               Apply branch protection rulesets (Main and Dev branches)
    --pages, --gh-pages   Setup GitHub Pages (copy gh-pages.yml workflow and docs/index.html)
    --release             Setup release workflow (copy release.yml workflow)
    --action              Shortcut for --release --pages --claude
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
    jd repo --rules                            # Apply branch protection rulesets
    jd repo --pages                            # Setup GitHub Pages
    jd repo --release                          # Setup release workflow
    jd repo --action                           # Setup release, pages, and JD workflows
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
    APPLE_TEAM_ID:            op://dev/apple/APPLE_TEAM_ID
    APPLE_DEVELOPER_EMAIL:    op://dev/apple/APPLE_DEVELOPER_EMAIL
    APPLE_CONNECT_EMAIL:      op://dev/apple/APPLE_CONNECT_EMAIL
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
    if ! secret_value=$(op read "$op_reference" 2>&1); then
        error "Failed to read $secret_name from 1Password: $op_reference"
        echo -e "${DIM}Error: $secret_value${NC}" >&2
        info "Make sure you're signed in to 1Password: op signin"
        return 1
    fi

    # Add secret to GitHub repository
    local gh_error
    if gh_error=$(echo "$secret_value" | gh secret set "$secret_name" 2>&1); then
        log "✓ Added $secret_name"
    else
        error "Failed to add $secret_name to GitHub repository"
        echo -e "${DIM}Error: $gh_error${NC}" >&2
        info "Make sure you have admin access to the repository"
        return 1
    fi
}

# Apply branch protection rulesets to the GitHub repository
apply_rulesets() {
    local rulesets_file="$JD_CLI_ROOT/data/rulesets.json"

    if [ ! -f "$rulesets_file" ]; then
        error "Rulesets file not found: $rulesets_file"
        return 1
    fi

    info "Applying branch protection rulesets..."

    # Get repository name with owner
    local repo_full_name
    if ! repo_full_name=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        error "Failed to get repository name"
        return 1
    fi

    # Apply Main branch ruleset
    info "Creating ruleset for Main branch..."
    local main_ruleset=$(jq -c '.main' "$rulesets_file")
    if echo "$main_ruleset" | gh api "repos/$repo_full_name/rulesets" --method POST --input - >/dev/null 2>&1; then
        log "✓ Main branch ruleset applied"
    else
        warning "Failed to apply Main branch ruleset (may already exist)"
    fi

    # Apply Dev branch ruleset
    info "Creating ruleset for Dev branch..."
    local dev_ruleset=$(jq -c '.dev' "$rulesets_file")
    if echo "$dev_ruleset" | gh api "repos/$repo_full_name/rulesets" --method POST --input - >/dev/null 2>&1; then
        log "✓ Dev branch ruleset applied"
    else
        warning "Failed to apply Dev branch ruleset (may already exist)"
    fi

    log "Branch protection rulesets configured"
}

# Copy Claude Code workflow files
setup_claude_workflows() {
    info "Setting up GitHub Actions workflows for JD..."

    # Create .github/workflows directory if it doesn't exist
    local workflows_dir=".github/workflows"
    if [ ! -d "$workflows_dir" ]; then
        info "Creating $workflows_dir directory..."
        if ! mkdir -p "$workflows_dir"; then
            error "Failed to create $workflows_dir directory"
            return 1
        fi
    fi

    # Copy workflow files if they don't exist
    local workflows=("jd.yml" "jd-review.yml")
    for workflow in "${workflows[@]}"; do
        local dest="$workflows_dir/$workflow"
        if [ -f "$dest" ]; then
            info "Workflow $workflow already exists, skipping..."
        else
            info "Copying $workflow to $workflows_dir..."
            local source="$JD_CLI_ROOT/data/$workflow"
            if [ ! -f "$source" ]; then
                error "Source workflow not found: $source"
                return 1
            fi
            if cp "$source" "$dest"; then
                log "✓ Copied $workflow"
            else
                error "Failed to copy $workflow"
                return 1
            fi
        fi
    done

    # Copy settings.json to .claude/ if it doesn't exist
    setup_claude_settings || return 1
}

# Copy settings.json to .claude/ directory
setup_claude_settings() {
    info "Setting up Claude settings..."

    # Create .claude directory if it doesn't exist
    local claude_dir=".claude"
    if [ ! -d "$claude_dir" ]; then
        info "Creating $claude_dir directory..."
        if ! mkdir -p "$claude_dir"; then
            error "Failed to create $claude_dir directory"
            return 1
        fi
    fi

    # Copy settings.json if it doesn't exist
    local dest="$claude_dir/settings.json"
    if [ -f "$dest" ]; then
        info "File $dest already exists, skipping..."
    else
        info "Copying settings.json to $claude_dir/..."
        local source="$JD_CLI_ROOT/data/settings.json"
        if [ ! -f "$source" ]; then
            error "Source settings.json not found: $source"
            return 1
        fi
        if cp "$source" "$dest"; then
            log "✓ Copied settings.json to $claude_dir/"
        else
            error "Failed to copy settings.json"
            return 1
        fi
    fi
}

# Setup GitHub Pages
setup_github_pages() {
    info "Setting up GitHub Pages..."

    # Create .github/workflows directory if it doesn't exist
    local workflows_dir=".github/workflows"
    if [ ! -d "$workflows_dir" ]; then
        info "Creating $workflows_dir directory..."
        if ! mkdir -p "$workflows_dir"; then
            error "Failed to create $workflows_dir directory"
            return 1
        fi
    fi

    # Copy gh-pages.yml workflow if it doesn't exist
    local workflow="gh-pages.yml"
    local dest="$workflows_dir/$workflow"
    if [ -f "$dest" ]; then
        info "Workflow $workflow already exists, skipping..."
    else
        info "Copying $workflow to $workflows_dir..."
        local source="$JD_CLI_ROOT/data/$workflow"
        if [ ! -f "$source" ]; then
            error "Source workflow not found: $source"
            return 1
        fi
        if cp "$source" "$dest"; then
            log "✓ Copied $workflow"
        else
            error "Failed to copy $workflow"
            return 1
        fi
    fi

    # Create docs directory with index.html if it doesn't exist
    if [ ! -d "docs" ]; then
        info "Creating docs directory..."
        if ! mkdir -p "docs"; then
            error "Failed to create docs directory"
            return 1
        fi
    fi

    local docs_index="docs/index.html"
    if [ -f "$docs_index" ]; then
        info "File $docs_index already exists, skipping..."
    else
        info "Copying index.html to docs/..."
        local source="$JD_CLI_ROOT/data/index.html"
        if [ ! -f "$source" ]; then
            error "Source index.html not found: $source"
            return 1
        fi
        if cp "$source" "$docs_index"; then
            log "✓ Copied index.html to docs/"
        else
            error "Failed to copy index.html"
            return 1
        fi
    fi

    log "GitHub Pages configured successfully"
}

# Setup release workflow
setup_release_workflow() {
    info "Setting up release workflow..."

    # Create .github/workflows directory if it doesn't exist
    local workflows_dir=".github/workflows"
    if [ ! -d "$workflows_dir" ]; then
        info "Creating $workflows_dir directory..."
        if ! mkdir -p "$workflows_dir"; then
            error "Failed to create $workflows_dir directory"
            return 1
        fi
    fi

    # Copy release.yml workflow if it doesn't exist
    local workflow="release.yml"
    local dest="$workflows_dir/$workflow"
    if [ -f "$dest" ]; then
        info "Workflow $workflow already exists, skipping..."
    else
        info "Copying $workflow to $workflows_dir..."
        local source="$JD_CLI_ROOT/data/$workflow"
        if [ ! -f "$source" ]; then
            error "Source workflow not found: $source"
            return 1
        fi
        if cp "$source" "$dest"; then
            log "✓ Copied $workflow"
        else
            error "Failed to copy $workflow"
            return 1
        fi
    fi

    log "Release workflow configured successfully"
}

# Create or update the JD label
create_jd_label() {
    info "Ensuring JD label exists..."

    # Get repository name with owner
    local repo_full_name
    if ! repo_full_name=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        error "Failed to get repository name"
        return 1
    fi

    # Check if label already exists
    local label_exists
    if label_exists=$(gh api "repos/$repo_full_name/labels/JD" 2>/dev/null); then
        # Label exists, update it to ensure correct color and description
        info "Updating existing JD label..."
        if gh api "repos/$repo_full_name/labels/JD" --method PATCH \
            -f color="7f3cf0" \
            -f description="AI Bot" >/dev/null 2>&1; then
            log "✓ JD label updated"
        else
            warning "Failed to update JD label"
            return 1
        fi
    else
        # Label doesn't exist, create it
        info "Creating JD label..."
        if gh api "repos/$repo_full_name/labels" --method POST \
            -f name="JD" \
            -f color="7f3cf0" \
            -f description="AI Bot" >/dev/null 2>&1; then
            log "✓ JD label created"
        else
            error "Failed to create JD label"
            return 1
        fi
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
    local add_rules=false
    local add_pages=false
    local add_release=false
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
            --rules)
                add_rules=true
                shift
                ;;
            --pages|--gh-pages)
                add_pages=true
                shift
                ;;
            --release)
                add_release=true
                shift
                ;;
            --action)
                add_release=true
                add_pages=true
                add_claude=true
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
    add_secret "GH_PAT" "op://dev/github/GH_PAT" || return 1

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
        add_secret "APPLE_TEAM_ID" "op://dev/apple/APPLE_TEAM_ID" || return 1
        add_secret "APPLE_DEVELOPER_EMAIL" "op://dev/apple/APPLE_DEVELOPER_EMAIL" || return 1
        add_secret "APPLE_CONNECT_EMAIL" "op://dev/apple/APPLE_CONNECT_EMAIL" || return 1
        add_secret "MATCH_REPOSITORY${secret_suffix}" "op://dev/fastlane/MATCH_REPOSITORY${secret_suffix}" || return 1
        add_secret "MATCH_PASSWORD${secret_suffix}" "op://dev/fastlane/MATCH_PASSWORD${secret_suffix}" || return 1
        #add_secret "GH_PAT" "op://dev/github/GH_PAT" || return 1
    fi

    # Apply branch protection rulesets if requested
    if [ "$add_rules" = true ]; then
        apply_rulesets || return 1
    fi

    # Setup GitHub Pages if requested
    if [ "$add_pages" = true ]; then
        setup_github_pages || return 1
    fi

    # Setup release workflow if requested
    if [ "$add_release" = true ]; then
        setup_release_workflow || return 1
    fi

    # Add Claude Code configuration if requested
    if [ "$add_claude" = true ]; then
        setup_claude_workflows || return 1
        create_jd_label || return 1
    fi

    log "Repository initialization complete!"

    # Show repository URL
    local repo_url=$(gh repo view --json url -q .url 2>/dev/null)
    [ -n "$repo_url" ] && info "Repository URL: $repo_url"
}
