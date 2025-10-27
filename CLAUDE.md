# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The jd CLI is a bash-based personal development toolkit distributed via npm. It wraps complex workflows (GitHub PRs, devcontainers, Python venvs) into simple commands with automatic dependency management.

## Architecture

### Core Components

**Entry Point** (`bin/jd`)

- Bootstraps the CLI by sourcing utility modules
- Parses global options (`--verbose`, `--version`, `--help`)
- Dynamically loads and executes command scripts from `commands/`
- Any new `.sh` file in `commands/` with an `execute_command()` function automatically becomes a subcommand

**Utility Layer** (`utils/`)

- `common.sh`: Shared functions for logging, git operations, user prompts, OS detection
- `dependency-check.sh`: Handles automatic installation of dependencies (gh, devcontainer CLI)

**Command Layer** (`commands/`)

- Each command is a self-contained bash script
- Must implement `execute_command()` function
- May implement `show_<command>_help()` for command-specific help
- Commands call `check_command_dependencies()` to ensure prerequisites

### Dependency Management Philosophy

The CLI uses "just-in-time" installation with user consent:

1. User runs a command (e.g., `jd pr`)
2. Command checks if dependencies exist via `check_command_dependencies()`
3. If missing, prompts user to auto-install (default: yes)
4. Installs via platform-specific package managers (brew/apt/npm)
5. For GitHub CLI, also guides through authentication flow

Key functions:

- `check_gh_cli()`: Installs GitHub CLI and authenticates
- `check_devcontainer_cli()`: Tries global npm install, falls back to local

## Development Workflow

### Local Development Setup

```bash
# Clone and setup
git clone https://github.com/starburst997/jd.git
cd jd
./scripts/setup-local.sh  # Installs deps, creates symlink
```

### Testing Changes

```bash
# After making changes, test directly (symlink created by setup)
jd <command> --help
jd <command> [args]
```

### Adding New Commands

1. Create `commands/mycommand.sh`
2. Make executable: `chmod +x commands/mycommand.sh`
3. Implement required functions:

   ```bash
   #!/usr/bin/env bash

   show_mycommand_help() {
       echo "Help text"
   }

   execute_command() {
       check_command_dependencies "mycommand"
       # Implementation
   }
   ```

4. Command automatically available as `jd mycommand`

**CRITICAL: When adding a new command, you MUST update documentation in ALL of these files:**

1. **`bin/jd`** - Add command to the `show_help()` function and examples section
2. **`README.md`** - Add to:
   - Features list at the top
   - Usage section with detailed examples and workflow
   - Dependency management section (if applicable)
   - Project structure section (`commands/` directory listing)
3. **`docs/index.html`** - Add a new command card to the commands section
4. **`utils/dependency-check.sh`** - Add dependency checking case to `check_command_dependencies()` if the command has prerequisites
5. **`completions/jd.bash`** - Add command to:
   - The `commands` variable list
   - Command-specific options in the case statement (if the command has flags beyond `--help`)
6. **`completions/jd.zsh`** - Add command to:
   - The `commands` array with description
   - Command-specific arguments in the case statement (if the command has flags beyond `--help`)

**Failing to update all documentation and completion files will result in an incomplete implementation.**

### Adding Flags to Existing Commands

**CRITICAL: When adding flags to an existing command, you MUST update ALL of these files:**

1. **Command file** (`commands/<command>.sh`) - Update:
   - The `show_<command>_help()` function with the new flag documentation
   - The options parsing case statement to handle the new flag
   - The execution logic to use the new flag

2. **`README.md`** - Update:
   - The command's usage examples to show the new flag
   - Add explanation of what the flag does in the appropriate section
   - Update any relevant workflow descriptions

3. **`docs/index.html`** - Update:
   - The command's usage line in the `command-usage` div to include the new flag
   - Add a new `<li>` item in the `args-list` with `arg-name` and `arg-desc` for the flag

4. **`completions/jd.bash`** - Add new flag to the command's options list in the case statement

5. **`completions/jd.zsh`** - Add new flag with description to the command's `_arguments` list

**Example: Adding `--rules` flag to the `repo` command requires updating:**
- `commands/repo.sh` (help text, parsing, logic)
- `README.md` (usage examples, flag explanation)
- `docs/index.html` (command usage line, args list)
- `completions/jd.bash` (add to `repo_opts`)
- `completions/jd.zsh` (add to `repo` case's `_arguments`)

**Failing to update ALL documentation files (README.md, docs/index.html) and completion scripts will result in an incomplete implementation.**

### Publishing New Versions

Done via github action

## Key Conventions

### Git Branch Detection

- Uses `git config --get init.defaultBranch` first
- Falls back to detecting `main` or `master` via `git show-ref`
- Then checks `refs/remotes/origin/HEAD`
- Function: `get_default_branch()` in `utils/common.sh`

### User Interaction

- Always use colored logging functions: `log()`, `error()`, `warning()`, `info()`
- Use `confirm()` for yes/no prompts (supports default answers)
- Enable verbose mode via `$VERBOSE` environment variable
- Debug output via `debug()` only shows when `--verbose` flag used

### Error Handling

- Use `set -e` in scripts (fail fast)
- Check preconditions (git repo, dependencies) before operations
- Return proper exit codes (0=success, 1=failure)
- Provide actionable error messages with manual fallback commands

### PATH Management

- `bin/jd` calculates `$ROOT_DIR` and exports as `$JD_CLI_ROOT`
- For local devcontainer CLI: `export PATH="$JD_CLI_ROOT/node_modules/.bin:$PATH"`
- Commands executed from user's working directory, not CLI directory

## Important Implementation Details

### PR Command (`commands/pr.sh`)

- Auto-generates PR title from branch name or commit messages
- Detects if branch contains "wip" or "draft" to suggest draft PR
- Respects GitHub PR templates if they exist in the repo
- Offers to push unpushed commits before creating PR
- Uses `gh pr create` with smart defaults

### Repo Command (`commands/repo.sh`)

- Initializes GitHub repository for the current directory
- Configures GitHub Actions secrets using 1Password CLI (`op`) and GitHub CLI (`gh`)
- Always adds bot secrets: `BOT_ID`, `BOT_KEY`
- Optional secret groups via flags:
  - `--npm`: Adds `NPM_TOKEN`
  - `--extensions`: Adds `VSCE_PAT`, `OVSX_PAT`
  - `--claude`: Adds `CLAUDE_CODE_OAUTH_TOKEN`
  - `--apple`: Adds Apple App Store, Fastlane, and GitHub PAT secrets
- Apple secrets support environment-specific suffixes via `--suffix` flag
- Dependencies: `gh`, `op` (checked via `check_command_dependencies`)

**Apple Secrets (`--apple` flag):**
- App Store Connect (with suffix support):
  - `APPSTORE_ISSUER_ID[_SUFFIX]`
  - `APPSTORE_KEY_ID[_SUFFIX]`
  - `APPSTORE_P8[_SUFFIX]`
- Apple Developer (no suffix):
  - `APPLE_TEAM_ID`
  - `APPLE_DEVELOPER_EMAIL`
  - `APPLE_CONNECT_EMAIL`
- Fastlane (with suffix support):
  - `MATCH_REPOSITORY[_SUFFIX]`
  - `MATCH_PASSWORD[_SUFFIX]`
- GitHub: `GH_PAT` (no suffix)

**Suffix Behavior (`--suffix` flag):**
- Only applies to `APPSTORE_*` and `MATCH_*` secrets
- Appends `_<SUFFIX>` to both the GitHub secret name AND the 1Password reference
- Example: `--suffix DEV` creates `APPSTORE_ISSUER_ID_DEV` from `op://dev/apple/APPSTORE_ISSUER_ID_DEV`
- Allows multiple environments (dev/staging/prod) to coexist in same repo

### Dev Command (`commands/dev.sh`)

- Applies devcontainer templates using `devcontainer templates apply`
- Default template: `ghcr.io/devcontainers/templates/nodejs-postgres`
- Can force overwrite with `--force` flag
- Lists available templates with `--list`

### Venv Command (`commands/venv.sh`)

- Creates virtual environment in `./venv` if missing
- Auto-installs from `requirements.txt` if present
- Prints activation command for user's shell

### Requirements Command (`commands/requirements.sh`)

- Uses `pip freeze` to capture installed packages
- Only works if virtual environment is active
- Overwrites existing `requirements.txt`

### Update Command (`commands/update.sh`)

- Self-updates via `npm install -g @jdboivin/cli@latest`
- Can check for updates without installing: `jd update --check`

### Claude-GitHub Command (`commands/claude-github.sh`)

- Runs `claude setup-token` to generate OAuth token
- Prompts user to manually paste the token (since `claude setup-token` expects manual copy)
- Updates 1Password secret at `op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN`
- Fetches all user's GitHub repositories via `gh repo list`
- Loops through repos and updates `CLAUDE_CODE_OAUTH_TOKEN` secret if it exists
- Provides summary statistics (updated/skipped/failed counts)
- Dependencies: `gh`, `op`, `claude` (all checked via `check_command_dependencies`)

### Completion Command (`commands/completion.sh`)

- Outputs shell completion scripts for bash or zsh
- Usage: `jd completion bash` or `jd completion zsh`
- Users load completions with: `eval "$(jd completion bash)"`
- Completion scripts located in `completions/` directory
- Auto-installed during `jd init` (can skip with `--skip-completions`)

### Shell Completions (`completions/`)

The CLI provides tab completion for bash and zsh shells:

- **`jd.bash`** - Bash completion script using `complete -F`
- **`jd.zsh`** - Zsh completion script using `#compdef` and `_arguments`

Both scripts provide:
- Command name completion
- Global option completion (`-v`, `--verbose`, `--help`, `--version`)
- Command-specific option completion (e.g., `jd pr --draft`, `jd dev --force`)
- Context-aware suggestions based on current command

Setup methods:
1. **Automatic**: `jd init` detects shell and adds completion to RC file
2. **Manual**: `eval "$(jd completion bash)"` in shell session
3. **Persistent Manual**: Add eval line to `~/.bashrc` or `~/.zshrc`

The init command's `setup_shell_completion()` function:
- Auto-detects user's shell via `$SHELL` environment variable (not script interpreter)
- Supports bash and zsh shells
- Checks if completion already configured (prevents duplicates)
- Creates timestamped backup of RC file before modification
- Adds completion line with comment marker for easy identification
- Handles edge cases where `$SHELL` is not standard (falls back to version variables)

## Common Tasks

```bash
# Test all commands work
jd --help
jd dev --help
jd pr --help

# Make scripts executable
chmod +x bin/jd commands/*.sh scripts/*.sh

# Test dependency checking without installing
JD_AUTO_INSTALL=false jd pr

# Test with verbose output
jd --verbose pr --draft

# Test shell completions
jd completion bash | head -20      # Verify bash completion output
jd completion zsh | head -20       # Verify zsh completion output
bash -n completions/jd.bash        # Validate bash syntax
zsh -n completions/jd.zsh          # Validate zsh syntax
eval "$(jd completion bash)"       # Load completions in current bash session
eval "$(jd completion zsh)"        # Load completions in current zsh session
```
