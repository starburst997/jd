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
    commands="dev pr merge repo npm venv requirements claude-github init update completion help"

    # Complete first argument (command or global option)
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${commands} ${global_opts}" -- ${cur}) )
        return 0
    fi

    # Command-specific completions
    case "${COMP_WORDS[1]}" in
        pr)
            local pr_opts="--title --body --base --head --draft --web --reviewers --assignees --labels --milestone --no-maintainer --template --no-claude --model -h --help"
            # If previous word was --model, suggest model options
            if [ "$prev" = "--model" ]; then
                COMPREPLY=( $(compgen -W "sonnet haiku opus" -- ${cur}) )
            else
                COMPREPLY=( $(compgen -W "${pr_opts}" -- ${cur}) )
            fi
            ;;
        merge)
            local merge_opts="--branch --clean -h --help"
            COMPREPLY=( $(compgen -W "${merge_opts}" -- ${cur}) )
            ;;
        dev)
            local dev_opts="--list --force -h --help"
            # Could add template names here if we want to be fancy
            COMPREPLY=( $(compgen -W "${dev_opts}" -- ${cur}) )
            ;;
        repo)
            local repo_opts="--npm --extensions --claude --apple --suffix --rules --public --description --no-init -h --help"
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
        completion)
            # Only suggest shell types
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "bash zsh -h --help" -- ${cur}) )
            fi
            ;;
        venv|requirements|claude-github|init|help)
            # These commands only have --help
            COMPREPLY=( $(compgen -W "-h --help" -- ${cur}) )
            ;;
    esac

    return 0
}

# Register the completion function
complete -F _jd_completions jd
