# jd

Personal development CLI tools for streamlined workflow with automated dependency management.

This is just a collection of cli commands I find personally useful and tailored to me.

## Features

- **`jd init`** - Setup and install CLI dependencies (optional first-time setup)
- **`jd dev`** - Apply devcontainer templates to projects with a single command
- **`jd pr`** - Create GitHub pull requests with smart defaults
- **`jd merge`** - Merge GitHub pull requests and cleanup branches with worktree support
- **`jd repo`** - Initialize GitHub repository and configure secrets from 1Password
- **`jd npm`** - Setup npm package with OIDC trusted publishing
- **`jd update`** - Self-update to latest version
- **`jd venv`** - Create and manage Python virtual environments
- **`jd requirements`** - Generate requirements.txt from active virtual environment
- **`jd claude-github`** - Update Claude Code OAuth token across all GitHub repositories and 1Password

## Quick Start

### Installation

#### Via npm

```bash
npm install -g @jdboivin/cli
```

#### Via Homebrew (Coming Soon)

```bash
brew tap jdboivin/tap
brew install jd
```

#### Via curl

```bash
curl -fsSL https://cli.jd.boiv.in/install.sh | bash
```

Uninstall

```bash
rm -rf ~/.jd && rm ~/.local/bin/jd
```

#### From Source

```bash
git clone https://github.com/starburst997/jd.git
cd jd
npm install
# Add alias to your rc files
echo "alias jd=\"$(pwd)/bin/jd\"" >> ~/.zshrc
# or
./scripts/setup-local.sh
```

## Usage

### Setup CLI Dependencies (Optional First-Time Setup)

```bash
# Full automated setup with CLI dependency installation
jd init
```

The init command helps you set up the jd CLI by:

- Checking for Node.js and npm
- Offering to install GitHub CLI if missing
- Configuring GitHub authentication
- Installing devcontainer CLI if missing
- Setting up shell completions for tab completion
- Verifying all tools are working

**Note:** This is an optional command that helps install CLI tools needed by jd commands.

### Apply DevContainer Template

```bash
# Apply default nodejs-postgres template
jd dev

# Apply with custom template ID
jd dev ghcr.io/my/template/custom

# Force overwrite existing .devcontainer
jd dev --force

# List available templates
jd dev --list
```

### Create GitHub Pull Request

```bash
# Create PR with AI-generated title and description
jd pr

# Create draft PR with AI generation
jd pr --draft

# Create PR with custom title (AI generates description)
jd pr --title "Add new feature"

# Disable AI generation, use fallback
jd pr --no-claude

# Use Haiku model for faster generation
jd pr --model haiku

# Use Opus model for higher quality
jd pr --model opus

# Create PR with custom base branch
jd pr --base develop

# Create PR and open in browser
jd pr --web

# Create PR with reviewers
jd pr --reviewers user1,user2

# Full example with custom title and body (no AI)
jd pr --title "Add new feature" --body "Custom description" --draft --reviewers teammate --labels enhancement
```

Smart PR features:

- **AI-powered title and description generation** using Claude CLI (enabled by default)
- Supports multiple Claude models: `sonnet` (default), `haiku`, `opus`
- Auto-generates title from branch name or recent commits (fallback)
- Creates PR body from commit history (fallback)
- Detects WIP/Draft branches
- Uses repository PR templates if available
- Auto-assigns yourself
- Offers to push changes if needed
- Custom title/body override AI generation

### Merge GitHub Pull Request

```bash
# Squash merge PR for current branch (default)
jd merge

# Regular merge PR for current branch
jd merge --type merge

# Rebase merge PR for current branch
jd merge --type rebase

# Merge PR for specific branch
jd merge --branch feature-x

# Specify merge type for specific branch
jd merge --branch feature-x --type merge

# Only cleanup old temporary branches
jd merge --clean
```

Smart merge features:

- **Auto-detects PR** for current branch using GitHub CLI
- **Squash merge by default** - can be customized with `--type` flag (squash, merge, or rebase)
- **Merges and deletes** remote branch automatically
- **Fetches latest** changes from origin after merge
- **Switches to default branch** and pulls latest changes
- **Worktree-aware** - creates temporary branch if default branch is checked out elsewhere
- **Auto-cleanup** - removes old temporary branches not in use
- **Handles uncommitted changes** gracefully

Worktree workflow:
1. When default branch is checked out in another worktree:
   - Creates unique temp branch (e.g., `main-temp-1`) based on latest `origin/main`
   - Switches to temp branch automatically
   - Cleans up old unused temp branches
2. When default branch is available:
   - Switches to default branch
   - Pulls latest changes
   - Cleans up temp branches

### Initialize GitHub Repository with Secrets

```bash
# Initialize private repository with bot secrets
jd repo

# Initialize with NPM token as well
jd repo --npm

# Initialize with extension publishing tokens
jd repo --extensions

# Initialize with Claude Code OAuth token
jd repo --claude

# Initialize with branch protection rulesets
jd repo --rules

# Initialize with all secrets and rulesets
jd repo --npm --extensions --claude --rules

# Create public repository
jd repo --public

# Create with description
jd repo --description "My awesome project"

# Use existing git repo (skip git init)
jd repo --no-init
```

The repo command integrates with 1Password CLI to securely add GitHub secrets:

**Always added:**

- `BOT_ID` - GitHub App bot ID
- `BOT_KEY` - GitHub App bot private key

**With `--npm` flag:**

- `NPM_TOKEN` - NPM publishing token

**With `--extensions` flag:**

- `VSCE_PAT` - Visual Studio Code Extension publishing token
- `OVSX_PAT` - Open VSX Registry publishing token

**With `--claude` flag:**

- `CLAUDE_CODE_OAUTH_TOKEN` - Claude Code OAuth token

**With `--rules` flag:**

- Applies branch protection rulesets for `main` and `dev` branches
- `main` branch: Prevents deletion, force pushes, and requires pull requests (merge/rebase allowed)
- `dev` branch: Prevents deletion and force pushes

Secret references in 1Password:

- BOT_ID: `op://dev/github-app/BOT_ID`
- BOT_KEY: `op://dev/github-app/BOT_KEY`
- NPM_TOKEN: `op://dev/npm/NPM_TOKEN`
- VSCE_PAT: `op://dev/extensions/VSCE_PAT`
- OVSX_PAT: `op://dev/extensions/OVSX_PAT`
- CLAUDE_CODE_OAUTH_TOKEN: `op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN`

### Setup npm Package with OIDC Publishing

```bash
# Setup npm package with OIDC trusted publishing
jd npm
```

This command automates the initial setup for npm OIDC trusted publishing:

1. **Reads package information** from your `package.json`
2. **Creates and publishes** a minimal `0.0.0-placeholder` version
3. **Opens the browser** to the npm package access settings page
4. **Provides instructions** for configuring OIDC trusted publishing

The npm command solves a key limitation: npm requires a package to exist before you can configure OIDC settings. After running this command:

- Your package will exist on npmjs.com
- You can configure OIDC trusted publishing through the web UI
- Future publishes will use OIDC (no tokens needed in CI/CD)
- The placeholder version will be replaced by your real package

**Prerequisites:**

- `package.json` in current directory
- npm account credentials for `npm login`
- GitHub Actions workflow with `id-token: write` permission

**After OIDC configuration:**

Your GitHub Actions can publish automatically using OIDC authentication - no npm tokens required!

### Update jd CLI

```bash
# Update to latest version
jd update

# Check for updates without installing
jd update --check

# Force reinstall
jd update --force
```

### Manage Python Virtual Environments

```bash
# Create new virtual environment or activate existing one
jd venv

# The command will:
# - Create a new venv if it doesn't exist
# - Activate the virtual environment
# - Automatically install requirements.txt if present
```

The venv command automatically handles:

- Detection of python3 or python
- Creation of virtual environment in ./venv
- Auto-installation of requirements.txt dependencies
- Smart activation messages

### Generate Python Requirements

```bash
# Generate requirements.txt from active virtual environment
jd requirements

# This uses pip freeze to capture all installed packages
```

Requirements workflow:

1. Create/activate venv: `jd venv`
2. Install packages: `pip install package1 package2`
3. Generate requirements: `jd requirements`
4. Commit requirements.txt to your repository

### Update Claude Code OAuth Token

```bash
# Update Claude Code OAuth token across all repositories and 1Password
jd claude-github
```

This command automates the process of updating Claude Code OAuth tokens (which expire after 1 year):

1. **Runs `claude setup-token`** to generate a new OAuth token
2. **Prompts you to paste** the token after browser authentication
3. **Updates 1Password** with the new token (`op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN`)
4. **Loops through all GitHub repositories** and updates the `CLAUDE_CODE_OAUTH_TOKEN` secret where it exists
5. **Provides summary** of updated, skipped, and failed repositories

**Prerequisites:**

- GitHub CLI (`gh`) - authenticated
- 1Password CLI (`op`) - authenticated
- Claude Code CLI (`claude`) - installed

**Workflow:**

The command will guide you through each step, showing authentication instructions in your browser, then systematically update all repositories that have the Claude Code OAuth token configured.

## Automated Dependency Management

The jd CLI automatically handles dependency installation:

### Required Dependencies

- Git
- Node.js >= 14.0.0
- npm >= 6.0.0

### Optional Dependencies (Auto-Installed)

When you run a command that needs a dependency, jd CLI will:

1. Detect if it's missing
2. Offer to install it automatically
3. Configure it if needed (e.g., GitHub authentication)

**GitHub CLI (`gh`)** - For `jd pr` and `jd repo` commands

- Auto-installs via brew (macOS), apt/yum (Linux), or winget (Windows)
- Guides through GitHub authentication

**1Password CLI (`op`)** - For `jd repo` and `jd claude-github` commands

- Required for managing GitHub secrets from 1Password
- Auto-installs via brew (macOS), winget (Windows)
- Install: https://developer.1password.com/docs/cli/get-started/

**Claude Code CLI (`claude`)** - For `jd claude-github` command

- Required for generating OAuth tokens
- Install: https://claude.com/code

**DevContainer CLI** - For `jd dev` command

- Auto-installs via npm
- Falls back to local installation if global fails

**Docker** - For dev containers (optional)

- Provides installation instructions

## Development

### Local Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/starburst997/jd.git
   cd jd
   ```

2. Run the setup script:

   ```bash
   ./scripts/setup-local.sh
   ```

   This will:

   - Install npm dependencies
   - Make scripts executable
   - Create a symlink for global usage (optional)

3. Test your changes:
   ```bash
   jd --help
   ```

### Project Structure

```
jd/
├── bin/
│   └── jd                    # Main CLI entry point
├── commands/
│   ├── dev.sh               # DevContainer command
│   ├── pr.sh                # GitHub PR command
│   ├── repo.sh              # GitHub repository initialization command
│   ├── npm.sh               # npm OIDC setup command
│   ├── init.sh              # Setup command
│   ├── update.sh            # Self-update command
│   ├── venv.sh              # Python virtual environment command
│   ├── requirements.sh      # Python requirements generator
│   └── claude-github.sh     # Claude Code OAuth token updater
├── data/
│   └── rulesets.json        # Branch protection ruleset definitions
├── utils/
│   ├── common.sh            # Common utilities
│   └── dependency-check.sh # Dependency management
├── scripts/
│   ├── check-dependencies.sh    # Post-install script
│   └── setup-local.sh           # Local development setup
└── package.json             # NPM package definition
```

### Adding New Commands

1. Create a new script in `commands/`:

   ```bash
   touch commands/mycommand.sh
   chmod +x commands/mycommand.sh
   ```

2. Implement the command with required functions:

   ```bash
   #!/usr/bin/env bash

   show_mycommand_help() {
       echo "Help text for mycommand"
   }

   execute_command() {
       # Command implementation
       # Use check_command_dependencies "mycommand" to check deps
   }
   ```

3. The command will automatically be available as `jd mycommand`

### Publishing

1. Update version in `package.json`
2. Commit changes
3. Create a new tag:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
4. Publish to npm:
   ```bash
   npm login
   npm publish --access public
   ```

## Configuration

The CLI follows these conventions:

- Uses your Git configuration for default branch detection
- Respects GitHub CLI authentication
- Works with existing `.devcontainer` configurations
- Uses repository PR templates when available

## Best Practices

### Distribution Strategy

The CLI is distributed via multiple channels for maximum accessibility:

1. **npm** - Primary distribution method

   - Handles Node.js dependencies automatically
   - Supports version management
   - Easy updates via `jd update`

2. **Homebrew** - macOS/Linux users (planned)

   - Familiar to many developers
   - Handles system dependencies

3. **Direct script** - Quick installation (planned)
   - No package manager required
   - Good for CI/CD environments

### Dependency Management Philosophy

- **Automated Installation** - Dependencies are installed automatically with user consent
- **Graceful Degradation** - Commands fail gracefully when dependencies are missing
- **Just-In-Time** - Dependencies are only installed when needed
- **User Control** - Always ask before installing, never force

### Version Management

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Tag releases in git
- Support self-updating via `jd update`

## Troubleshooting

### Permission Errors

If you get permission errors during global npm install:

```bash
# Option 1: Use npx (recommended)
npx @jdboivin/cli init

# Option 2: Fix npm permissions
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
npm install -g @jdboivin/cli
```

### GitHub Authentication Issues

If GitHub CLI authentication fails:

```bash
# Manually authenticate
gh auth login

# Check status
gh auth status
```

### DevContainer CLI Not Found

If devcontainer command isn't found after installation:

```bash
# Install globally
npm install -g @devcontainers/cli

# Or use jd init to auto-install
jd init
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests if applicable
5. Submit a pull request

## License

MIT

## Author

JD Boivin

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/starburst997/jd/issues) page.
