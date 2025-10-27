#compdef jd

# Zsh completion script for jd CLI
# This script provides tab completion for all jd commands and their options

_jd() {
    local -a commands
    local -a global_opts
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Define available commands with descriptions
    commands=(
        'dev:Apply devcontainer template to current project'
        'pr:Create GitHub pull request with defaults'
        'merge:Merge GitHub pull request and cleanup branches'
        'repo:Initialize GitHub repository and configure secrets'
        'npm:Setup npm package with OIDC trusted publishing'
        'venv:Create or activate Python virtual environment'
        'requirements:Generate requirements.txt from virtual environment'
        'claude-github:Update Claude Code OAuth token across GitHub repos and 1Password'
        'init:Setup and install CLI dependencies (optional first-time setup)'
        'update:Update jd CLI to latest version'
        'completion:Generate shell completion scripts'
        'help:Show help message'
    )

    # Parse arguments
    _arguments -C \
        '(-v --verbose)'{-v,--verbose}'[Enable verbose output]' \
        '(-h --help)'{-h,--help}'[Show help message]' \
        '--version[Show version]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe 'command' commands
            ;;
        args)
            case $words[1] in
                pr)
                    _arguments \
                        '--title[PR title (AI generates description if not provided)]:title:' \
                        '--body[PR body]:body:' \
                        '--base[Base branch]:branch:' \
                        '--head[Head branch]:branch:' \
                        '--draft[Create as draft PR]' \
                        '--auto-draft[Auto-detect draft from branch name (wip/draft prefixes)]' \
                        '--web[Open PR in web browser]' \
                        '--reviewers[Comma-separated list of reviewers]:reviewers:' \
                        '--assignees[Comma-separated list of assignees]:assignees:' \
                        '--labels[Comma-separated list of labels]:labels:' \
                        '--milestone[Milestone ID or title]:milestone:' \
                        '--no-maintainer[Disable maintainer edits]' \
                        '--template[Use PR template file]:file:_files' \
                        '--no-claude[Disable Claude AI generation (use fallback)]' \
                        '--model[Claude model to use]:model:(sonnet haiku opus)' \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
                merge)
                    _arguments \
                        '--branch[Branch name to find PR for]:branch:' \
                        '--type[Merge type]:type:(squash merge rebase)' \
                        '--clean[Only cleanup old temporary branches]' \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
                dev)
                    _arguments \
                        '--list[List available templates]' \
                        '--force[Force overwrite existing files]' \
                        '(-h --help)'{-h,--help}'[Show help message]' \
                        '1:template:'
                    ;;
                repo)
                    _arguments \
                        '--npm[Also add NPM_TOKEN secret]' \
                        '--extensions[Also add VSCE_PAT and OVSX_PAT secrets]' \
                        '--claude[Also add CLAUDE_CODE_OAUTH_TOKEN secret]' \
                        '--apple[Also add Apple App Store and Fastlane secrets]' \
                        '--suffix[Add suffix to APPSTORE and MATCH_ secrets]:suffix:' \
                        '--rules[Apply branch protection rulesets (Main and Dev branches)]' \
                        '--public[Create public repository (default: private)]' \
                        '--description[Repository description]:description:' \
                        '--no-init[Skip git initialization (use existing repo)]' \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
                npm)
                    _arguments \
                        '--scope[Package scope]:scope:' \
                        '--access[Package access (public/restricted)]:access:(public restricted)' \
                        '--repo-url[Repository URL]:url:' \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
                update)
                    _arguments \
                        '--check[Check for updates without installing]' \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
                completion)
                    _arguments \
                        '1:shell:(bash zsh)' \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
                venv|requirements|claude-github|init|help)
                    _arguments \
                        '(-h --help)'{-h,--help}'[Show help message]'
                    ;;
            esac
            ;;
    esac
}

# Register the completion function
# The #compdef directive at the top tells compinit to register this function
# When eval'd directly, we need to call compdef if it's available (after compinit)
if [[ -n ${ZSH_VERSION-} ]] && (( ${+functions[compdef]} )); then
    compdef _jd jd
fi
