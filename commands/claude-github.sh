#!/usr/bin/env bash

show_claude_github_help() {
    cat << EOF
Usage: jd claude-github

Updates the CLAUDE_CODE_OAUTH_TOKEN secret across all GitHub repositories and 1Password.

This command will:
  1. Run 'claude setup-token' to generate a new OAuth token
  2. Prompt you to paste the token from Claude Code
  3. Update the token in 1Password (op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN)
  4. Loop through all your GitHub repositories
  5. Update the CLAUDE_CODE_OAUTH_TOKEN secret if it exists in each repo

Prerequisites:
  - GitHub CLI (gh) - authenticated
  - 1Password CLI (op) - authenticated
  - Claude Code CLI (claude) - installed

Options:
  --help    Show this help message

Example:
  jd claude-github
EOF
}

execute_command() {
    check_command_dependencies "claude-github"

    log "Starting Claude Code OAuth token update process..."
    echo ""

    # Step 1: Run claude setup-token
    info "Step 1: Generating new OAuth token with 'claude setup-token'"
    info "Please follow the instructions in your browser to authenticate."
    echo ""

    # Run the command but don't capture output - let user see the instructions
    claude setup-token || {
        error "Failed to run 'claude setup-token'. Please ensure Claude Code CLI is installed."
        return 1
    }

    echo ""
    echo ""

    # Step 2: Prompt user to paste the token
    info "Step 2: Please paste the OAuth token from Claude Code below:"
    echo -n "Token: "
    read -r OAUTH_TOKEN

    # Validate token is not empty
    if [[ -z "$OAUTH_TOKEN" ]]; then
        error "No token provided. Aborting."
        return 1
    fi

    # Trim whitespace
    OAUTH_TOKEN=$(echo "$OAUTH_TOKEN" | xargs)

    log "Token received (length: ${#OAUTH_TOKEN} characters)"
    echo ""

    # Step 3: Update 1Password
    info "Step 3: Updating token in 1Password..."
    if op item edit claude CLAUDE_CODE_OAUTH_TOKEN="$OAUTH_TOKEN" --vault dev >/dev/null 2>&1; then
        log "Successfully updated 1Password secret: op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN"
    else
        warning "Failed to update 1Password secret. Continuing with GitHub updates..."
    fi
    echo ""

    # Step 4: Get all user repositories
    info "Step 4: Fetching all GitHub repositories..."
    REPOS=$(gh repo list --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')

    if [[ -z "$REPOS" ]]; then
        warning "No repositories found."
        return 0
    fi

    REPO_COUNT=$(echo "$REPOS" | wc -l | xargs)
    log "Found $REPO_COUNT repositories"
    echo ""

    # Step 5: Loop through repositories and update secret
    info "Step 5: Updating CLAUDE_CODE_OAUTH_TOKEN secret in repositories..."
    echo ""

    UPDATED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0

    while IFS= read -r repo; do
        # Check if secret exists
        if gh secret list --repo "$repo" 2>/dev/null | grep -q "CLAUDE_CODE_OAUTH_TOKEN"; then
            debug "Updating secret in $repo..."

            if gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo "$repo" --body "$OAUTH_TOKEN" >/dev/null 2>&1; then
                log "✓ Updated: $repo"
                ((UPDATED_COUNT++))
            else
                warning "✗ Failed: $repo"
                ((FAILED_COUNT++))
            fi
        else
            debug "Skipping $repo (secret does not exist)"
            ((SKIPPED_COUNT++))
        fi
    done <<< "$REPOS"

    echo ""
    log "Update complete!"
    log "  Updated: $UPDATED_COUNT repositories"
    log "  Skipped: $SKIPPED_COUNT repositories (secret does not exist)"

    if [[ $FAILED_COUNT -gt 0 ]]; then
        warning "  Failed: $FAILED_COUNT repositories"
    fi
}
