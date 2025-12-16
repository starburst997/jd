#!/usr/bin/env bash

# Automate release process: merge dev->main, bump versions, create GitHub release

show_release_help() {
    cat <<EOF
Automate release process

Usage: jd release [OPTIONS]

Options:
    --dry-run         Show what would be done without making changes
    -h, --help        Show this help message

Process:
    1. Check for uncommitted changes
    2. Merge dev branch into main (normal merge, no rebase)
    3. Switch back to dev branch
    4. Increment MINOR version in root package.json
    5. Update version in apps/*/app.config.ts and apps/*/package.json
    6. Commit and push changes with "Version bump" message
    7. Create GitHub release with auto-generated notes on main branch

Requirements:
    - Must be in a git repository
    - GitHub CLI (gh) must be installed and authenticated
    - Root package.json must exist

Examples:
    jd release              # Run full release process
    jd release --dry-run    # Preview changes without executing

EOF
}

# Increment minor version (e.g., "2025.7.0" -> "2025.8.0")
increment_minor_version() {
    local version="$1"

    # Extract major, minor, patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    # Increment minor, reset patch to 0
    minor=$((minor + 1))
    patch=0

    echo "${major}.${minor}.${patch}"
}

# Update version in a JSON file (package.json)
update_json_version() {
    local file="$1"
    local new_version="$2"
    local dry_run="$3"

    if [ ! -f "$file" ]; then
        return 1
    fi

    if [ "$dry_run" = true ]; then
        log "Would update version in $file to $new_version"
        return 0
    fi

    # Use jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        local tmp_file="${file}.tmp"
        jq --arg ver "$new_version" '.version = $ver' "$file" > "$tmp_file"
        mv "$tmp_file" "$file"
    else
        # Fallback to sed (less robust but works)
        sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$file"
        rm -f "${file}.bak"
    fi

    log "Updated version in $file to $new_version"
    return 0
}

# Update version in app.config.ts
update_app_config_version() {
    local file="$1"
    local new_version="$2"
    local dry_run="$3"

    if [ ! -f "$file" ]; then
        return 1
    fi

    if [ "$dry_run" = true ]; then
        log "Would update version in $file to $new_version"
        return 0
    fi

    # Replace version line in app.config.ts
    sed -i.bak "s/version: \"[^\"]*\"/version: \"$new_version\"/" "$file"
    rm -f "${file}.bak"

    log "Updated version in $file to $new_version"
    return 0
}

execute_command() {
    # Check if in git repo
    check_git_repo || return 1

    # Check dependencies
    check_command_dependencies "release" || return 1

    # Default values
    local dry_run=false

    # Variables used across steps (declared at function scope for summary)
    local current_version=""
    local new_version=""
    local release_tag=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_release_help
                return 0
                ;;
            *)
                error "Unknown option: $1"
                show_release_help
                return 1
                ;;
        esac
    done

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        warning "You have uncommitted changes"
        if ! confirm "Continue with release anyway?" "n"; then
            info "Commit your changes first with: git add . && git commit -m 'message'"
            return 1
        fi
    fi

    # Get current branch
    local current_branch=$(get_current_branch)
    local default_branch=$(get_default_branch)

    # Ensure we're on the default branch (likely "dev")
    if [ "$current_branch" != "$default_branch" ]; then
        warning "Not on default branch ($default_branch), switching..."
        if [ "$dry_run" = false ]; then
            git checkout "$default_branch" || {
                error "Failed to switch to $default_branch"
                return 1
            }
        fi
    fi

    # Ensure main branch exists
    if ! git show-ref --verify --quiet refs/heads/main; then
        error "Main branch does not exist"
        return 1
    fi

    # Step 1: Merge dev into main
    info "Step 1: Merging $default_branch into main..."
    if [ "$dry_run" = false ]; then
        git checkout main || {
            error "Failed to checkout main branch"
            return 1
        }

        if ! git merge "$default_branch" --no-ff -m "Merge $default_branch into main for release"; then
            error "Merge failed - please resolve conflicts manually"
            git merge --abort 2>/dev/null
            git checkout "$default_branch"
            return 1
        fi

        log "✓ Merged $default_branch into main"

        # Push main branch
        info "Pushing main branch..."
        git push origin main || {
            error "Failed to push main branch"
            return 1
        }
    else
        log "Would merge $default_branch into main"
    fi

    # Step 2: Switch back to dev branch
    info "Step 2: Switching back to $default_branch..."
    if [ "$dry_run" = false ]; then
        git checkout "$default_branch" || {
            error "Failed to switch back to $default_branch"
            return 1
        }
        log "✓ Switched back to $default_branch"
    else
        log "Would switch back to $default_branch"
    fi

    # Step 3: Check for root package.json
    if [ ! -f "package.json" ]; then
        error "Root package.json not found"
        return 1
    fi

    # Get current version
    local current_version
    if command -v jq &> /dev/null; then
        current_version=$(jq -r '.version' package.json)
    else
        current_version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
    fi

    if [ -z "$current_version" ]; then
        error "Could not read version from package.json"
        return 1
    fi

    info "Current version: $current_version"

    # Calculate release tag now (before version bump) so it's available for summary
    local cur_major cur_minor cur_patch
    IFS='.' read -r cur_major cur_minor cur_patch <<< "$current_version"
    release_tag="v${cur_major}.${cur_minor}"

    # Step 4: Increment minor version
    new_version=$(increment_minor_version "$current_version")
    info "New version: $new_version"

    # Update root package.json
    info "Step 3: Updating root package.json..."
    update_json_version "package.json" "$new_version" "$dry_run" || {
        error "Failed to update root package.json"
        return 1
    }

    # Step 5: Update versions in apps/*/app.config.ts and apps/*/package.json
    if [ -d "apps" ]; then
        info "Step 4: Updating versions in apps/*..."

        local updated_count=0
        for app_dir in apps/*/; do
            if [ ! -d "$app_dir" ]; then
                continue
            fi

            local app_name=$(basename "$app_dir")
            debug "Checking $app_dir"

            # Update app.config.ts if it exists
            if [ -f "${app_dir}app.config.ts" ]; then
                update_app_config_version "${app_dir}app.config.ts" "$new_version" "$dry_run"
                updated_count=$((updated_count + 1))
            fi

            # Update package.json if it exists
            if [ -f "${app_dir}package.json" ]; then
                update_json_version "${app_dir}package.json" "$new_version" "$dry_run"
                updated_count=$((updated_count + 1))
            fi
        done

        if [ $updated_count -eq 0 ]; then
            warning "No app.config.ts or package.json files found in apps/*"
        else
            log "✓ Updated $updated_count file(s) in apps/*"
        fi
    else
        debug "No apps/ directory found, skipping app version updates"
    fi

    # Step 6: Commit and push
    info "Step 5: Committing and pushing version bump..."
    if [ "$dry_run" = false ]; then
        # Add root package.json (required)
        debug "Staging package.json..."
        if ! git add package.json; then
            error "Failed to stage package.json"
            return 1
        fi

        # Add app files if they exist (optional)
        if [ -d "apps" ]; then
            for app_dir in apps/*/; do
                [ -f "${app_dir}app.config.ts" ] && git add "${app_dir}app.config.ts" 2>/dev/null
                [ -f "${app_dir}package.json" ] && git add "${app_dir}package.json" 2>/dev/null
            done
        fi

        # Verify we have staged changes
        if git diff --cached --quiet; then
            error "No changes were staged - this is unexpected after version bump"
            error "Check if package.json was actually modified"
            git status
            return 1
        fi

        # Show what will be committed
        debug "Staged changes:"
        [ "$VERBOSE" = true ] && git diff --cached --stat

        # Commit
        debug "Committing version bump..."
        local commit_output
        if ! commit_output=$(git commit -m "Version bump" 2>&1); then
            error "Failed to commit version bump"
            error "Git output: $commit_output"
            return 1
        fi
        debug "$commit_output"

        # Push to dev branch
        debug "Pushing to $default_branch..."
        local push_output
        if ! push_output=$(git push origin "$default_branch" 2>&1); then
            error "Failed to push to $default_branch"
            error "Git output: $push_output"
            return 1
        fi
        debug "$push_output"

        log "✓ Committed and pushed version bump"
    else
        log "Would commit and push version bump"
    fi

    # Step 7: Create GitHub release (using the version that was merged to main)
    info "Step 6: Creating GitHub release on main..."
    debug "Release tag: $release_tag"

    if [ "$dry_run" = false ]; then
        # Create release with auto-generated notes
        debug "Running: gh release create $release_tag --target main --title $release_tag --generate-notes"
        local release_output
        if ! release_output=$(gh release create "$release_tag" \
            --target main \
            --title "$release_tag" \
            --generate-notes 2>&1); then
            error "Failed to create GitHub release"
            error "gh output: $release_output"
            info "You can create it manually with: gh release create $release_tag --target main --title $release_tag --generate-notes"
            return 1
        fi
        log "✓ Created GitHub release: $release_tag"

        # Get release URL
        local release_url
        release_url=$(gh release view "$release_tag" --json url -q .url 2>/dev/null)
        [ -n "$release_url" ] && info "Release URL: $release_url"
    else
        log "Would create GitHub release: $release_tag on main branch"
    fi

    log "✓ Release process completed successfully!"
    info "Summary:"
    info "  - Merged $default_branch into main"
    info "  - Created release: $release_tag"
    info "  - Bumped version for next cycle: $current_version -> $new_version"
}
