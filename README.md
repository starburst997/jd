# jd CLI

Personal development CLI tools for streamlined workflow with automated dependency management.

## Features

- **`jd dev`** - Apply devcontainer templates to projects with a single command
- **`jd pr`** - Create GitHub pull requests with smart defaults
- **`jd init`** - Automated setup and dependency installation
- **`jd update`** - Self-update to latest version

## Quick Start

### One-Line Install (Recommended)

```bash
npx @jdboivin/jd-cli init
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
npm install -g @jdboivin/jd-cli
jd init  # Run automated setup
```

#### Via Homebrew (Coming Soon)

```bash
brew tap jdboivin/tap
brew install jd-cli
```

#### Via curl (Coming Soon)

```bash
curl -fsSL https://raw.githubusercontent.com/jdboivin/jd-cli/main/install.sh | bash
```

#### From Source

```bash
git clone https://github.com/jdboivin/jd-cli.git
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

### Update jd CLI

```bash
# Update to latest version
jd update

# Check for updates without installing
jd update --check

# Force reinstall
jd update --force
```

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

**GitHub CLI (`gh`)** - For `jd pr` command
- Auto-installs via brew (macOS), apt/yum (Linux), or winget (Windows)
- Guides through GitHub authentication

**DevContainer CLI** - For `jd dev` command
- Auto-installs via npm
- Falls back to local installation if global fails

**Docker** - For dev containers (optional)
- Provides installation instructions

## Development

### Local Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/jdboivin/jd-cli.git
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
│   ├── init.sh              # Setup command
│   └── update.sh            # Self-update command
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
npx @jdboivin/jd-cli init

# Option 2: Fix npm permissions
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
npm install -g @jdboivin/jd-cli
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

For issues and feature requests, please use the [GitHub Issues](https://github.com/jdboivin/jd-cli/issues) page.