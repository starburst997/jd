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
git clone https://github.com/starburst997/jd-cli.git
cd jd-cli
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

- Self-updates via `npm install -g @jdboivin/jd-cli@latest`
- Can check for updates without installing: `jd update --check`

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
```
