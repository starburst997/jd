#!/usr/bin/env bash

# Merge GitHub pull request and cleanup branches

show_merge_help() {
    cat <<EOF
Merge GitHub pull request and cleanup branches

Usage: jd merge [OPTIONS]

Options:
    --branch BRANCH   Branch name to find PR for (defaults to current branch)
    --clean           Only cleanup temp branches (no merge)
    -h, --help        Show this help message

Features:
    - Auto-detects PR for current branch using gh CLI
    - Merges the PR on GitHub
    - Fetches latest changes from origin
    - Switches to updated default branch
    - Worktree-aware: creates temp branch if default branch is checked out elsewhere
    - Auto-cleanup of old temp branches

Examples:
    jd merge                     # Merge PR for current branch
    jd merge --branch feature-x  # Merge PR for specific branch
    jd merge --clean            # Only cleanup old temp branches

EOF
}

# Get next available temp branch name
get_next_temp_branch() {
    local base_branch="$1"
    local counter=1
    local temp_name="${base_branch}-temp-${counter}"

    # Find the next available number
    while git show-ref --verify --quiet "refs/heads/$temp_name" 2>/dev/null; do
        counter=$((counter + 1))
        temp_name="${base_branch}-temp-${counter}"
    done

    echo "$temp_name"
}

# Get list of temp branches that are NOT currently checked out
get_unused_temp_branches() {
    local base_branch="$1"
    local pattern="^${base_branch}-temp-[0-9]+$"

    # Get all temp branches
    local all_temp_branches=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E "$pattern")

    if [ -z "$all_temp_branches" ]; then
        return 0
    fi

    # Get all checked out branches (in all worktrees)
    local checked_out_branches=$(git worktree list --porcelain | grep "^branch " | sed 's/^branch //')

    # Filter out checked out branches
    local unused_branches=""
    while IFS= read -r branch; do
        if ! echo "$checked_out_branches" | grep -q "^${branch}$"; then
            unused_branches+="$branch"$'\n'
        fi
    done <<< "$all_temp_branches"

    echo -n "$unused_branches"
}

# Cleanup unused temp branches
cleanup_temp_branches() {
    local base_branch="$1"

    info "Cleaning up unused temp branches..."

    local unused=$(get_unused_temp_branches "$base_branch")

    if [ -z "$unused" ]; then
        log "No unused temp branches to clean up"
        return 0
    fi

    local count=0
    while IFS= read -r branch; do
        [ -z "$branch" ] && continue
        info "Deleting branch: $branch"
        if git branch -D "$branch" &>/dev/null; then
            count=$((count + 1))
        else
            warning "Failed to delete branch: $branch"
        fi
    done <<< "$unused"

    log "Cleaned up $count temp branch(es)"
}

# Check if we're in a worktree
is_worktree() {
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    [[ "$git_dir" == *".git/worktrees/"* ]]
}

# Check if a branch is checked out in any worktree
is_branch_checked_out() {
    local branch="$1"
    git worktree list --porcelain | grep -q "^branch refs/heads/${branch}$"
}

execute_command() {
    # Check if in git repo
    check_git_repo || return 1

    # Check dependencies
    check_command_dependencies "merge" || return 1

    # Default values
    local branch=""
    local clean_only=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                branch="$2"
                shift 2
                ;;
            --clean)
                clean_only=true
                shift
                ;;
            -h|--help)
                show_merge_help
                return 0
                ;;
            *)
                error "Unknown option: $1"
                show_merge_help
                return 1
                ;;
        esac
    done

    # Get default branch
    local default_branch=$(get_default_branch)
    debug "Default branch: $default_branch"

    # If --clean flag is set, only do cleanup
    if [ "$clean_only" = true ]; then
        cleanup_temp_branches "$default_branch"
        return 0
    fi

    # Get branch to merge
    [ -z "$branch" ] && branch=$(get_current_branch)

    if [ -z "$branch" ]; then
        error "Could not determine branch name"
        return 1
    fi

    # Don't allow merging default branch
    if [ "$branch" = "$default_branch" ]; then
        error "Cannot merge the default branch ($default_branch)"
        return 1
    fi

    info "Looking for PR for branch: $branch"

    # Find PR for this branch
    local pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null)

    if [ -z "$pr_number" ]; then
        error "No open PR found for branch: $branch"
        info "Create a PR first with: jd pr"
        return 1
    fi

    log "Found PR #$pr_number"

    # Get PR details
    local pr_title=$(gh pr view "$pr_number" --json title --jq '.title' 2>/dev/null)
    info "PR: $pr_title"

    # Merge the PR
    info "Merging PR #$pr_number..."
    if ! gh pr merge "$pr_number" --merge --delete-branch 2>/dev/null; then
        error "Failed to merge PR #$pr_number"
        info "You may need to resolve conflicts or check PR status"
        return 1
    fi

    log "PR merged successfully"

    # Only auto-switch if we used the current branch (not --branch flag)
    if [ -z "$1" ] || [ "$1" != "--branch" ]; then
        info "Updating local repository..."

        # Fetch latest changes
        if ! git fetch origin 2>/dev/null; then
            warning "Failed to fetch from origin"
            return 0
        fi

        # Try to switch to default branch
        if is_branch_checked_out "$default_branch"; then
            warning "Default branch '$default_branch' is checked out in another worktree"

            # Create temp branch based on latest origin default branch
            local temp_branch=$(get_next_temp_branch "$default_branch")
            info "Creating temporary branch: $temp_branch"

            if git branch "$temp_branch" "origin/$default_branch" 2>/dev/null; then
                if git checkout "$temp_branch" 2>/dev/null; then
                    log "Switched to temporary branch: $temp_branch"
                    info "Based on latest origin/$default_branch"

                    # Cleanup old temp branches
                    cleanup_temp_branches "$default_branch"
                else
                    error "Failed to checkout temporary branch"
                    return 1
                fi
            else
                error "Failed to create temporary branch"
                return 1
            fi
        else
            # Default branch is not checked out elsewhere, switch to it
            if git checkout "$default_branch" 2>/dev/null; then
                # Pull latest changes
                if git pull origin "$default_branch" 2>/dev/null; then
                    log "Switched to $default_branch and updated"

                    # Cleanup old temp branches
                    cleanup_temp_branches "$default_branch"
                else
                    warning "Switched to $default_branch but failed to pull latest changes"
                    info "You may have uncommitted changes"
                fi
            else
                warning "Failed to switch to $default_branch"
                info "You may have uncommitted changes"
            fi
        fi
    fi

    success "Merge complete!"
}
