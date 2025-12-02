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
    --kubeconfig [NS]     Generate and add KUBE_CONFIG secret for namespace NS
                          Creates 3 namespaces: NS, NS-dev, NS-pr
                          If NS not specified, auto-detects from charts/*.yaml
    --kubeconfig-minimal [NS]  Generate and add KUBE_CONFIG secret for single namespace NS
                          If NS not specified, auto-detects from charts/*.yaml
    --rules               Apply branch protection rulesets (Main and Dev branches)
                          Main: prevents deletion and force pushes
                          Dev: prevents deletion and force pushes
    --rules-strict        Apply strict branch protection rulesets
                          Main: prevents deletion, force pushes, and requires pull requests
                          Dev: prevents deletion and force pushes
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
    jd repo --rules                            # Apply default branch protection rulesets
    jd repo --rules-strict                     # Apply strict rulesets (requires PRs on main)
    jd repo --pages                            # Setup GitHub Pages
    jd repo --release                          # Setup release workflow
    jd repo --action                           # Setup release, pages, and JD workflows
    jd repo --kubeconfig                       # Auto-detect namespace from charts/*.yaml
    jd repo --kubeconfig myapp                 # Generate KUBE_CONFIG for myapp, myapp-dev, myapp-pr
    jd repo --kubeconfig-minimal               # Auto-detect namespace, single namespace only
    jd repo --kubeconfig-minimal myapp         # Generate KUBE_CONFIG for myapp only
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
    local strict_mode="${1:-false}"
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

    # Determine which Main branch ruleset to use
    local main_key="main"
    if [ "$strict_mode" = true ]; then
        main_key="main_strict"
        info "Using strict rulesets (requires pull requests for Main branch)"
    else
        info "Using default rulesets (no pull request requirement for Main branch)"
    fi

    # Apply Main branch ruleset
    info "Creating ruleset for Main branch..."
    local main_ruleset=$(jq -c ".$main_key" "$rulesets_file")
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
    local repo_root="$1"
    info "Setting up GitHub Actions workflows for JD..."

    # Create .github/workflows directory if it doesn't exist
    local workflows_dir="$repo_root/.github/workflows"
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
    setup_claude_settings "$repo_root" || return 1
}

# Copy settings.json to .claude/ directory
setup_claude_settings() {
    local repo_root="$1"
    info "Setting up Claude settings..."

    # Create .claude directory if it doesn't exist
    local claude_dir="$repo_root/.claude"
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
    local repo_root="$1"
    info "Setting up GitHub Pages..."

    # Create .github/workflows directory if it doesn't exist
    local workflows_dir="$repo_root/.github/workflows"
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
    if [ ! -d "$repo_root/docs" ]; then
        info "Creating docs directory..."
        if ! mkdir -p "$repo_root/docs"; then
            error "Failed to create docs directory"
            return 1
        fi
    fi

    local docs_index="$repo_root/docs/index.html"
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
    local repo_root="$1"
    info "Setting up release workflow..."

    # Create .github/workflows directory if it doesn't exist
    local workflows_dir="$repo_root/.github/workflows"
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

# Detect namespace from charts/*.yaml files
detect_kubeconfig_namespace() {
    local repo_root="$1"
    local charts_dir="$repo_root/charts"
    local namespace=""

    # Check if charts directory exists
    if [ ! -d "$charts_dir" ]; then
        debug "Charts directory not found: $charts_dir"
        return 1
    fi

    # First try values.yaml or values.yml
    for values_file in "$charts_dir/values.yaml" "$charts_dir/values.yml"; do
        if [ -f "$values_file" ]; then
            namespace=$(grep -E '^namespace:\s*\S+' "$values_file" 2>/dev/null | head -1 | sed 's/^namespace:\s*//' | tr -d ' "'"'"'')
            if [ -n "$namespace" ]; then
                debug "Found namespace in $values_file: $namespace"
                echo "$namespace"
                return 0
            fi
        fi
    done

    # If not found in values.yaml/yml, search other yaml files in charts/
    for yaml_file in "$charts_dir"/*.yaml "$charts_dir"/*.yml; do
        if [ -f "$yaml_file" ]; then
            namespace=$(grep -E '^namespace:\s*\S+' "$yaml_file" 2>/dev/null | head -1 | sed 's/^namespace:\s*//' | tr -d ' "'"'"'')
            if [ -n "$namespace" ]; then
                debug "Found namespace in $yaml_file: $namespace"
                echo "$namespace"
                return 0
            fi
        fi
    done

    debug "No namespace found in charts/*.yaml files"
    return 1
}

# Generate and add KUBE_CONFIG secret
setup_kubeconfig() {
    local namespace="$1"
    local minimal="$2"
    local repo_full_name

    info "Generating kubeconfig for namespace: $namespace"

    # Get repository name with owner
    if ! repo_full_name=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        error "Failed to get repository name"
        return 1
    fi

    # Create temporary directory for output
    local temp_dir
    temp_dir=$(mktemp -d)

    # Build the command
    local kubeconfig_script="$JD_CLI_ROOT/scripts/generate-kubeconfig.sh"
    if [ ! -f "$kubeconfig_script" ]; then
        error "generate-kubeconfig.sh not found at: $kubeconfig_script"
        rm -rf "$temp_dir"
        return 1
    fi

    local cmd="$kubeconfig_script \"$namespace\" \"$repo_full_name\" --output-dir \"$temp_dir\""
    if [ "$minimal" = true ]; then
        cmd="$cmd --minimal"
    fi

    # Run the script
    info "Running kubeconfig generation script..."
    if ! eval "$cmd"; then
        error "Failed to generate kubeconfig"
        rm -rf "$temp_dir"
        return 1
    fi

    # Read the generated kubeconfig
    local kubeconfig_file="$temp_dir/kubeconfig.yaml"
    if [ ! -f "$kubeconfig_file" ]; then
        error "Kubeconfig file not created at: $kubeconfig_file"
        rm -rf "$temp_dir"
        return 1
    fi

    # Add the secret to GitHub
    info "Adding KUBE_CONFIG secret to GitHub repository..."
    if cat "$kubeconfig_file" | gh secret set KUBE_CONFIG 2>&1; then
        log "✓ Added KUBE_CONFIG secret"
    else
        error "Failed to add KUBE_CONFIG to GitHub repository"
        rm -rf "$temp_dir"
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
    log "Kubeconfig setup complete for namespace: $namespace"
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
    local rules_strict=false
    local add_pages=false
    local add_release=false
    local suffix=""
    local add_kubeconfig=false
    local kubeconfig_namespace=""
    local kubeconfig_minimal=false
    local visibility="private"
    local description=""
    local skip_init=false
    local repo_root=""

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
            --kubeconfig)
                add_kubeconfig=true
                # Check if next arg is a namespace (not another flag or empty)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    kubeconfig_namespace="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --kubeconfig-minimal)
                add_kubeconfig=true
                kubeconfig_minimal=true
                # Check if next arg is a namespace (not another flag or empty)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    kubeconfig_namespace="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --rules)
                add_rules=true
                shift
                ;;
            --rules-strict)
                add_rules=true
                rules_strict=true
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

    # Get the repository root directory
    if git rev-parse --git-dir > /dev/null 2>&1; then
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$repo_root" ]; then
            # Fallback to current directory if we can't determine the root
            repo_root=$(pwd)
        fi
    else
        # Not in a git repo yet, use current directory
        repo_root=$(pwd)
    fi
    debug "Repository root: $repo_root"

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
        apply_rulesets "$rules_strict" || return 1
    fi

    # Setup GitHub Pages if requested
    if [ "$add_pages" = true ]; then
        setup_github_pages "$repo_root" || return 1
    fi

    # Setup release workflow if requested
    if [ "$add_release" = true ]; then
        setup_release_workflow "$repo_root" || return 1
    fi

    # Add Claude Code configuration if requested
    if [ "$add_claude" = true ]; then
        setup_claude_workflows "$repo_root" || return 1
        create_jd_label || return 1
    fi

    # Setup kubeconfig if requested
    if [ "$add_kubeconfig" = true ]; then
        # Check kubectl dependency
        check_command_dependencies "repo-kubeconfig" || return 1

        # Auto-detect namespace if not provided
        if [ -z "$kubeconfig_namespace" ]; then
            info "No namespace specified, searching in charts/*.yaml..."
            kubeconfig_namespace=$(detect_kubeconfig_namespace "$repo_root")
            if [ -z "$kubeconfig_namespace" ]; then
                error "No namespace found in charts/*.yaml files"
                info "Please specify a namespace: jd repo --kubeconfig <namespace>"
                return 1
            fi
            log "Detected namespace: $kubeconfig_namespace"
        fi

        setup_kubeconfig "$kubeconfig_namespace" "$kubeconfig_minimal" || return 1
    fi

    log "Repository initialization complete!"

    # Show repository URL
    local repo_url=$(gh repo view --json url -q .url 2>/dev/null)
    [ -n "$repo_url" ] && info "Repository URL: $repo_url"
}
