#!/usr/bin/env bash

# Bash completion script for jd CLI
# This script provides tab completion for all jd commands and their options

_jd_completions() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Global options
    local global_opts="-v --verbose -h --help --version"

    # All available commands
    commands="dev pr merge repo npm venv requirements cleanup claude-github pg release init update completion help"

    # Complete first argument (command or global option)
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${commands} ${global_opts}" -- ${cur}) )
        return 0
    fi

    # Command-specific completions
    case "${COMP_WORDS[1]}" in
        pr)
            local pr_opts="--title --body --base --head --draft --auto-draft --web --reviewers --assignees --labels --milestone --no-maintainer --template --no-claude --model -h --help"
            # If previous word was --model, suggest model options
            if [ "$prev" = "--model" ]; then
                COMPREPLY=( $(compgen -W "sonnet haiku opus" -- ${cur}) )
            else
                COMPREPLY=( $(compgen -W "${pr_opts}" -- ${cur}) )
            fi
            ;;
        merge)
            local merge_opts="--branch --type --clean -h --help"
            # If previous word was --type, suggest merge type options
            if [ "$prev" = "--type" ]; then
                COMPREPLY=( $(compgen -W "squash merge rebase" -- ${cur}) )
            else
                COMPREPLY=( $(compgen -W "${merge_opts}" -- ${cur}) )
            fi
            ;;
        dev)
            local dev_opts="--list --force -h --help"
            # Could add template names here if we want to be fancy
            COMPREPLY=( $(compgen -W "${dev_opts}" -- ${cur}) )
            ;;
        repo)
            local repo_opts="--npm --extensions --claude --apple --suffix --rules --rules-strict --pages --gh-pages --release --action --public --description --no-init -h --help"
            COMPREPLY=( $(compgen -W "${repo_opts}" -- ${cur}) )
            ;;
        npm)
            local npm_opts="--scope --access --repo-url -h --help"
            COMPREPLY=( $(compgen -W "${npm_opts}" -- ${cur}) )
            ;;
        update)
            local update_opts="--check -h --help"
            COMPREPLY=( $(compgen -W "${update_opts}" -- ${cur}) )
            ;;
        cleanup)
            local cleanup_opts="-p --path -i --include-hidden -n --dry-run -s --skip-mac-cleanup -h --help"
            COMPREPLY=( $(compgen -W "${cleanup_opts}" -- ${cur}) )
            ;;
        completion)
            # Only suggest shell types
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "bash zsh -h --help" -- ${cur}) )
            fi
            ;;
        init)
            local init_opts="--skip-deps --skip-completions --force -h --help"
            COMPREPLY=( $(compgen -W "${init_opts}" -- ${cur}) )
            ;;
        release)
            local release_opts="--dry-run -h --help"
            COMPREPLY=( $(compgen -W "${release_opts}" -- ${cur}) )
            ;;
        venv|requirements|claude-github|pg|help)
            # These commands only have --help
            COMPREPLY=( $(compgen -W "-h --help" -- ${cur}) )
            ;;
    esac

    return 0
}

# Register the completion function
complete -F _jd_completions jd
