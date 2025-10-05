#!/usr/bin/env bash

# Create GitHub pull request with smart defaults

show_pr_help() {
    cat <<EOF
Create GitHub pull request with smart defaults

Usage: jd pr [OPTIONS]

Options:
    --title TITLE     PR title (defaults to branch name)
    --body BODY       PR body/description
    --base BRANCH     Base branch (defaults to main/master)
    --head BRANCH     Head branch (defaults to current branch)
    --draft           Create as draft PR
    --web             Open PR in web browser after creation
    --reviewers LIST  Comma-separated list of reviewers
    --assignees LIST  Comma-separated list of assignees
    --labels LIST     Comma-separated list of labels
    --milestone ID    Milestone ID or title
    --no-maintainer   Disable maintainer edits
    --template FILE   Use PR template file
    -h, --help        Show this help message

Smart Features:
    - Auto-detects conventional commit format for title
    - Uses recent commit messages for PR body if not specified
    - Detects WIP/Draft indicators in branch name
    - Auto-assigns yourself if no assignees specified
    - Uses repository's default PR template if exists

Examples:
    jd pr                                    # Create PR with smart defaults
    jd pr --draft                           # Create draft PR
    jd pr --title "Add feature" --web      # Custom title and open in browser
    jd pr --reviewers user1,user2          # Request reviews
    jd pr --base develop                   # PR against develop branch

EOF
}

# Generate PR title from branch name or commits
generate_pr_title() {
    local branch="$1"
    local title=""

    # Try to extract from branch name (e.g., feature/add-login -> Add login)
    if [[ "$branch" =~ ^(feature|fix|docs|style|refactor|test|chore)/(.+)$ ]]; then
        local type="${BASH_REMATCH[1]}"
        local desc="${BASH_REMATCH[2]}"
        # Replace dashes/underscores with spaces and capitalize
        desc=$(echo "$desc" | sed 's/[-_]/ /g' | sed 's/\b\(.\)/\u\1/g')

        case "$type" in
            feature) title="Add $desc" ;;
            fix) title="Fix $desc" ;;
            docs) title="Update documentation for $desc" ;;
            style) title="Style improvements for $desc" ;;
            refactor) title="Refactor $desc" ;;
            test) title="Add tests for $desc" ;;
            chore) title="Chore: $desc" ;;
            *) title="$desc" ;;
        esac
    else
        # Use the most recent commit message
        title=$(git log -1 --pretty=format:"%s" 2>/dev/null)
    fi

    [ -z "$title" ] && title="$branch"
    echo "$title"
}

# Generate PR body from recent commits
generate_pr_body() {
    local base_branch="$1"
    local head_branch="$2"
    local template_file="$3"

    local body=""

    # Check for PR template
    if [ -n "$template_file" ] && [ -f "$template_file" ]; then
        body=$(cat "$template_file")
    elif [ -f ".github/pull_request_template.md" ]; then
        body=$(cat ".github/pull_request_template.md")
    elif [ -f ".github/PULL_REQUEST_TEMPLATE.md" ]; then
        body=$(cat ".github/PULL_REQUEST_TEMPLATE.md")
    elif [ -f "docs/pull_request_template.md" ]; then
        body=$(cat "docs/pull_request_template.md")
    else
        # Generate from commits
        local commits=$(git log --oneline "$base_branch..$head_branch" 2>/dev/null)
        if [ -n "$commits" ]; then
            body="## Changes\n\n"
            body+="### Commits\n"
            while IFS= read -r commit; do
                body+="- $commit\n"
            done <<< "$commits"

            body+="\n## Type of Change\n"
            body+="- [ ] Bug fix\n"
            body+="- [ ] New feature\n"
            body+="- [ ] Breaking change\n"
            body+="- [ ] Documentation update\n"

            body+="\n## Testing\n"
            body+="- [ ] Tests pass locally\n"
            body+="- [ ] Added new tests\n"
        else
            body="## Description\n\nPlease describe your changes.\n\n## Type of Change\n\n- [ ] Bug fix\n- [ ] New feature\n- [ ] Breaking change\n- [ ] Documentation update"
        fi
    fi

    echo "$body"
}

# Check if branch indicates WIP/Draft
is_draft_branch() {
    local branch="$1"
    [[ "$branch" =~ ^(wip|draft|WIP|DRAFT)[-/] ]] && return 0
    [[ "$branch" =~ [-/](wip|draft|WIP|DRAFT)$ ]] && return 0
    return 1
}

execute_command() {
    # Check if in git repo
    check_git_repo || return 1

    # Check dependencies
    check_command_dependencies "pr" || return 1

    # Default values
    local title=""
    local body=""
    local base_branch=""
    local head_branch=""
    local draft=false
    local open_web=false
    local reviewers=""
    local assignees=""
    local labels=""
    local milestone=""
    local no_maintainer=false
    local template_file=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --title)
                title="$2"
                shift 2
                ;;
            --body)
                body="$2"
                shift 2
                ;;
            --base)
                base_branch="$2"
                shift 2
                ;;
            --head)
                head_branch="$2"
                shift 2
                ;;
            --draft)
                draft=true
                shift
                ;;
            --web)
                open_web=true
                shift
                ;;
            --reviewers)
                reviewers="$2"
                shift 2
                ;;
            --assignees)
                assignees="$2"
                shift 2
                ;;
            --labels)
                labels="$2"
                shift 2
                ;;
            --milestone)
                milestone="$2"
                shift 2
                ;;
            --no-maintainer)
                no_maintainer=true
                shift
                ;;
            --template)
                template_file="$2"
                shift 2
                ;;
            -h|--help)
                show_pr_help
                return 0
                ;;
            *)
                error "Unknown option: $1"
                show_pr_help
                return 1
                ;;
        esac
    done

    # Get branch information
    [ -z "$head_branch" ] && head_branch=$(get_current_branch)
    [ -z "$base_branch" ] && base_branch=$(get_default_branch)

    # Check if already on base branch
    if [ "$head_branch" = "$base_branch" ]; then
        error "Cannot create PR: currently on base branch ($base_branch)"
        info "Please create a feature branch first"
        return 1
    fi

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        warning "You have uncommitted changes"
        if ! confirm "Create PR anyway?" "n"; then
            info "Commit your changes first with: git add . && git commit -m 'message'"
            return 1
        fi
    fi

    # Push current branch if needed
    if ! git ls-remote --exit-code origin "$head_branch" &>/dev/null; then
        log "Pushing branch to remote..."
        git push -u origin "$head_branch" || return 1
    else
        # Check if local is ahead of remote
        local ahead=$(git rev-list --count "origin/$head_branch..$head_branch" 2>/dev/null)
        if [ "$ahead" -gt 0 ]; then
            log "Pushing latest changes..."
            git push origin "$head_branch" || return 1
        fi
    fi

    # Auto-detect draft status
    if [ "$draft" = false ] && is_draft_branch "$head_branch"; then
        info "Auto-detected draft branch pattern"
        draft=true
    fi

    # Generate title if not provided
    [ -z "$title" ] && title=$(generate_pr_title "$head_branch")

    # Generate body if not provided
    [ -z "$body" ] && body=$(generate_pr_body "$base_branch" "$head_branch" "$template_file")

    # Auto-assign self if no assignees
    if [ -z "$assignees" ]; then
        assignees="@me"
    fi

    # Build gh pr create command
    local gh_cmd="gh pr create"
    gh_cmd+=" --title \"$title\""
    gh_cmd+=" --body \"$body\""
    gh_cmd+=" --base \"$base_branch\""
    gh_cmd+=" --head \"$head_branch\""

    [ "$draft" = true ] && gh_cmd+=" --draft"
    [ -n "$reviewers" ] && gh_cmd+=" --reviewer \"$reviewers\""
    [ -n "$assignees" ] && gh_cmd+=" --assignee \"$assignees\""
    [ -n "$labels" ] && gh_cmd+=" --label \"$labels\""
    [ -n "$milestone" ] && gh_cmd+=" --milestone \"$milestone\""
    [ "$no_maintainer" = true ] && gh_cmd+=" --no-maintainer-edit"
    [ "$open_web" = true ] && gh_cmd+=" --web"

    # Create PR
    info "Creating pull request..."
    debug "Command: $gh_cmd"

    if eval "$gh_cmd"; then
        log "Pull request created successfully"

        # Show PR URL if not opening in web
        if [ "$open_web" = false ]; then
            local pr_url=$(gh pr view --json url -q .url 2>/dev/null)
            [ -n "$pr_url" ] && info "PR URL: $pr_url"
        fi
    else
        error "Failed to create pull request"
        return 1
    fi
}