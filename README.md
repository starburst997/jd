# jd

Personal development CLI tools for streamlined workflow with automated dependency management.

This is just a collection of cli commands I find personally useful and tailored to me.

## Features

- **`jd init`** - Automated setup and dependency installation
- **`jd dev`** - Apply devcontainer templates to projects with a single command
- **`jd pr`** - Create GitHub pull requests with smart defaults
- **`jd repo`** - Initialize GitHub repository and configure secrets from 1Password
- **`jd update`** - Self-update to latest version
- **`jd venv`** - Create and manage Python virtual environments
- **`jd requirements`** - Generate requirements.txt from active virtual environment

## Quick Start

### One-Line Install (Recommended)

```bash
npx @jdboivin/cli init
```

This will:

1. Install the jd CLI
2. Check all system requirements
3. Install missing dependencies (with your permission)
4. Configure GitHub authentication if needed
5. Verify everything is working

### Manual Installation

#### Via npm

```bash
npm install -g @jdboivin/cli
jd init  # Run automated setup
```

#### Via Homebrew (Coming Soon)

```bash
brew tap jdboivin/tap
brew install cli
```

#### Via curl

```bash
curl -fsSL https://cli.jd.boiv.in/install.sh | bash
```

#### From Source

```bash
git clone https://github.com/starburst997/jd-cli.git
cd jd-cli
npm install
./scripts/setup-local.sh
```

## Usage

### Initialize (First Time Setup)

```bash
# Full automated setup with dependency installation
jd init

# Skip dependency checks (manual setup)
jd init --skip-deps
```

The init command will:

- Check for Node.js and npm
- Offer to install GitHub CLI if missing
- Configure GitHub authentication
- Install devcontainer CLI if missing
- Verify all commands are working

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
# Create PR with smart defaults
jd pr

# Create draft PR
jd pr --draft

# Create PR with custom base branch
jd pr --base develop

# Create PR and open in browser
jd pr --web

# Create PR with reviewers
jd pr --reviewers user1,user2

# Full example
jd pr --title "Add new feature" --draft --reviewers teammate --labels enhancement
```

Smart PR features:

- Auto-generates title from branch name or recent commits
- Creates PR body from commit history
- Detects WIP/Draft branches
- Uses repository PR templates if available
- Auto-assigns yourself
- Offers to push changes if needed

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

# Initialize with all secrets
jd repo --npm --extensions --claude

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

Secret references in 1Password:

- BOT_ID: `op://dev/github-app/BOT_ID`
- BOT_KEY: `op://dev/github-app/BOT_KEY`
- NPM_TOKEN: `op://dev/npm/NPM_TOKEN`
- VSCE_PAT: `op://dev/extensions/VSCE_PAT`
- OVSX_PAT: `op://dev/extensions/OVSX_PAT`
- CLAUDE_CODE_OAUTH_TOKEN: `op://dev/claude/CLAUDE_CODE_OAUTH_TOKEN`

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

**1Password CLI (`op`)** - For `jd repo` command

- Required for managing GitHub secrets from 1Password
- Install: https://developer.1password.com/docs/cli/get-started/

**DevContainer CLI** - For `jd dev` command

- Auto-installs via npm
- Falls back to local installation if global fails

**Docker** - For dev containers (optional)

- Provides installation instructions

## Development

### Local Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/starburst997/jd-cli.git
   cd jd-cli
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
jd-cli/
├── bin/
│   └── jd                    # Main CLI entry point
├── commands/
│   ├── dev.sh               # DevContainer command
│   ├── pr.sh                # GitHub PR command
│   ├── repo.sh              # GitHub repository initialization command
│   ├── init.sh              # Setup command
│   ├── update.sh            # Self-update command
│   ├── venv.sh              # Python virtual environment command
│   └── requirements.sh      # Python requirements generator
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

For issues and feature requests, please use the [GitHub Issues](https://github.com/starburst997/jd-cli/issues) page.
