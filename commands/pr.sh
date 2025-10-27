#!/usr/bin/env bash

# Create GitHub pull request with smart defaults

show_pr_help() {
    cat <<EOF
Create GitHub pull request with smart defaults

Usage: jd pr [OPTIONS]

Options:
    --title TITLE     PR title (defaults to AI-generated or branch name)
    --body BODY       PR body/description (defaults to AI-generated)
    --base BRANCH     Base branch (defaults to main/master)
    --head BRANCH     Head branch (defaults to current branch)
    --draft           Create as draft PR
    --auto-draft      Auto-detect draft from branch name (wip/draft prefixes)
    --web             Open PR in web browser after creation
    --reviewers LIST  Comma-separated list of reviewers
    --assignees LIST  Comma-separated list of assignees
    --labels LIST     Comma-separated list of labels
    --milestone ID    Milestone ID or title
    --no-maintainer   Disable maintainer edits
    --template FILE   Use PR template file
    --no-claude       Disable Claude AI generation (use fallback generation)
    --model MODEL     Claude model to use: sonnet (default), haiku, or opus
    -h, --help        Show this help message

Smart Features:
    - AI-powered title and description generation using Claude CLI
    - Auto-detects conventional commit format for title (fallback)
    - Uses recent commit messages for PR body if not specified (fallback)
    - Auto-assigns yourself if no assignees specified
    - Uses repository's default PR template if exists

Examples:
    jd pr                                    # Create PR with AI-generated content
    jd pr --draft                           # Create draft PR with AI generation
    jd pr --auto-draft                      # Auto-detect draft from branch name
    jd pr --title "Add feature"             # Custom title, AI-generated body
    jd pr --no-claude                       # Disable AI, use fallback generation
    jd pr --model haiku                     # Use Haiku model for faster generation
    jd pr --title "Fix bug" --body "..."   # Custom title and body (no AI)
    jd pr --reviewers user1,user2          # Request reviews
    jd pr --base develop                   # PR against develop branch

EOF
}

# Generate PR title and body using Claude CLI
generate_with_claude() {
    local base_branch="$1"
    local head_branch="$2"
    local model="$3"
    local generate_title="$4"  # true/false
    local custom_title="$5"     # empty or custom title

    # Get git information (only committed changes)
    local commits=$(git log --oneline "$base_branch..$head_branch" 2>/dev/null)
    local changes=$(git diff "$base_branch...$head_branch" --stat 2>/dev/null)
    local diff=$(git diff "$base_branch...$head_branch" 2>/dev/null | head -n 500)

    # Claude CLI accepts simple aliases: sonnet, haiku, opus
    # These automatically use the latest versions
    local model_id="$model"

    local prompt=""

    if [ "$generate_title" = true ]; then
        # Generate both title and description
        prompt="Based on the following git diff and commits, generate a concise PR title and description.

Respond with the following format:
TITLE: [Your generated title here]

DESCRIPTION:
[Your generated description here in markdown format]

Include a summary section explaining what was changed and why, and a test plan section with specific things to test. Keep it concise and professional.

Commits:
$commits

Changes summary:
$changes

Here's a sample of the actual diff (truncated if too long):
$diff"
    else
        # Generate only description with custom title
        prompt="Based on the following git diff and commits, generate a concise PR description for a pull request titled '$custom_title'. Include a summary section explaining what was changed and why, and a test plan section with specific things to test. Keep it concise and professional.

Commits:
$commits

Changes summary:
$changes

Here's a sample of the actual diff (truncated if too long):
$diff

Format the response as markdown suitable for a GitHub PR description."
    fi

    # Try to use Claude CLI
    if command -v claude &> /dev/null; then
        debug "Generating with Claude using model: $model_id"
        local claude_response
        claude_response=$(echo "$prompt" | claude --model "$model_id" 2>/dev/null)

        if [ -n "$claude_response" ]; then
            if [ "$generate_title" = true ]; then
                # Extract title and description
                local generated_title=$(echo "$claude_response" | grep "^TITLE:" | sed 's/^TITLE: //')
                local generated_body=$(echo "$claude_response" | sed -n '/^DESCRIPTION:/,$ p' | sed '1d')

                if [ -n "$generated_title" ] && [ -n "$generated_body" ]; then
                    echo "TITLE:$generated_title"
                    echo "BODY:$generated_body"
                    return 0
                fi
            else
                # Only body was generated
                echo "BODY:$claude_response"
                return 0
            fi
        fi
    fi

    # Return failure if Claude generation didn't work
    return 1
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
    local auto_draft=false
    local open_web=false
    local reviewers=""
    local assignees=""
    local labels=""
    local milestone=""
    local no_maintainer=false
    local template_file=""
    local use_claude=true
    local claude_model="sonnet"

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
            --auto-draft)
                auto_draft=true
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
            --no-claude)
                use_claude=false
                shift
                ;;
            --model)
                claude_model="$2"
                # Validate model
                if [[ ! "$claude_model" =~ ^(sonnet|haiku|opus)$ ]]; then
                    error "Invalid model: $claude_model (must be: sonnet, haiku, or opus)"
                    return 1
                fi
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

    # Ensure base branch is pushed to origin (so PR will be against latest)
    if ! ensure_branch_pushed "$base_branch" "Base branch"; then
        error "Cannot create PR without pushing base branch"
        return 1
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

    # Auto-detect draft status if flag is enabled
    if [ "$auto_draft" = true ] && [ "$draft" = false ] && is_draft_branch "$head_branch"; then
        info "Auto-detected draft branch pattern"
        draft=true
    fi

    # Try to generate with Claude if enabled and not all fields provided
    local claude_generated=false
    if [ "$use_claude" = true ] && { [ -z "$title" ] || [ -z "$body" ]; }; then
        info "Generating PR content with Claude ($claude_model)..."

        local generate_title_flag=false
        local title_for_claude=""

        # Determine what to generate
        if [ -z "$title" ] && [ -z "$body" ]; then
            # Generate both title and body
            generate_title_flag=true
        elif [ -z "$body" ] && [ -n "$title" ]; then
            # Generate only body with custom title
            generate_title_flag=false
            title_for_claude="$title"
        fi

        # Call Claude generation
        local claude_output
        if claude_output=$(generate_with_claude "$base_branch" "$head_branch" "$claude_model" "$generate_title_flag" "$title_for_claude"); then
            claude_generated=true

            # Parse the output
            if [ "$generate_title_flag" = true ]; then
                title=$(echo "$claude_output" | grep "^TITLE:" | sed 's/^TITLE://')
                body=$(echo "$claude_output" | sed -n '/^BODY:/,$ p' | sed 's/^BODY://')
            else
                body=$(echo "$claude_output" | sed 's/^BODY://')
            fi

            debug "Claude generation successful"
        else
            warning "Claude generation failed, falling back to default generation"
        fi
    fi

    # Fallback to default generation if not using Claude or Claude failed
    if [ -z "$title" ]; then
        title=$(generate_pr_title "$head_branch")
    fi

    if [ -z "$body" ]; then
        body=$(generate_pr_body "$base_branch" "$head_branch" "$template_file")
    fi

    # Auto-assign self if no assignees
    if [ -z "$assignees" ]; then
        assignees="@me"
    fi

    # Create PR - call gh directly to avoid eval issues with multiline body
    info "Creating pull request..."

    # Build arguments array
    local gh_args=(
        "pr" "create"
        "--title" "$title"
        "--body" "$body"
        "--base" "$base_branch"
        "--head" "$head_branch"
    )

    [ "$draft" = true ] && gh_args+=("--draft")
    [ -n "$reviewers" ] && gh_args+=("--reviewer" "$reviewers")
    [ -n "$assignees" ] && gh_args+=("--assignee" "$assignees")
    [ -n "$labels" ] && gh_args+=("--label" "$labels")
    [ -n "$milestone" ] && gh_args+=("--milestone" "$milestone")
    [ "$no_maintainer" = true ] && gh_args+=("--no-maintainer-edit")
    [ "$open_web" = true ] && gh_args+=("--web")

    if gh "${gh_args[@]}"; then
        log "Pull request created successfully"

        # Show PR URL if not opening in web
        if [ "$open_web" = false ]; then
            local pr_url=$(gh pr view --json url -q .url 2>/dev/null)
            [ -n "$pr_url" ] && info "PR URL: $pr_url"
        fi
    else
        run_with_error_capture "Failed to create pull request" gh "${gh_args[@]}"
        info "Common issues:"
        info "  - GitHub authentication needed (run: gh auth login)"
        info "  - PR already exists for this branch"
        info "  - Invalid branch or base branch"
        return 1
    fi
}