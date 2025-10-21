#!/usr/bin/env bash

# jd CLI Installer
# Usage: curl -fsSL https://cli.jd.boiv.in/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="${HOME}/.jd"
BIN_DIR="${HOME}/.local/bin"

# GitHub repository
GITHUB_REPO="starburst997/jd"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"

# Logging functions
log() {
    echo -e "${BLUE}==>${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}!${NC} $*"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect download tool
get_download_tool() {
    if command_exists curl; then
        echo "curl"
    elif command_exists wget; then
        echo "wget"
    else
        echo ""
    fi
}

# Download file using available tool
download_file() {
    local url="$1"
    local output="$2"
    local tool
    tool=$(get_download_tool)

    case "$tool" in
        curl)
            curl -fsSL "$url" -o "$output"
            ;;
        wget)
            wget -q "$url" -O "$output"
            ;;
        *)
            error "Neither curl nor wget found. Please install one of them."
            return 1
            ;;
    esac
}

# Get latest release version from GitHub
get_latest_version() {
    local tool
    tool=$(get_download_tool)

    local response
    case "$tool" in
        curl)
            response=$(curl -fsSL "${GITHUB_API}/releases/latest")
            ;;
        wget)
            response=$(wget -qO- "${GITHUB_API}/releases/latest")
            ;;
        *)
            error "Neither curl nor wget found."
            return 1
            ;;
    esac

    echo "$response" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
}

# Detect shell config file
get_shell_config() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "${HOME}/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        if [ -f "${HOME}/.bashrc" ]; then
            echo "${HOME}/.bashrc"
        else
            echo "${HOME}/.bash_profile"
        fi
    else
        # Default to bashrc
        echo "${HOME}/.bashrc"
    fi
}

# Add PATH to shell config
setup_path() {
    local shell_config
    shell_config=$(get_shell_config)

    # Check if PATH is already set
    if [ -f "$shell_config" ] && grep -q "/.local/bin" "$shell_config"; then
        success "PATH already configured in $shell_config"
        return 0
    fi

    log "Adding ${BIN_DIR} to PATH in $shell_config"

    # Create config file if it doesn't exist
    touch "$shell_config"

    # Add PATH export
    cat >> "$shell_config" << 'EOF'

# jd CLI
export PATH="${HOME}/.local/bin:${PATH}"
EOF

    success "PATH configured in $shell_config"
}

# Main installation function
install_jd() {
    local version="$1"

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   jd CLI Installation Script         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Check for unzip
    if ! command_exists unzip; then
        error "unzip is required but not installed."
        error "Please install unzip and try again."
        exit 1
    fi

    # Get latest version if not specified
    if [ -z "$version" ]; then
        log "Fetching latest version..."
        version=$(get_latest_version)
        if [ -z "$version" ]; then
            error "Failed to fetch latest version"
            exit 1
        fi
        success "Latest version: $version"
    fi

    # Remove 'v' prefix if present
    local clean_version="${version#v}"

    # Create temporary directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Download source zip
    local zip_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${version}.zip"
    local zip_file="${tmp_dir}/jd.zip"

    log "Downloading jd CLI ${version}..."
    if ! download_file "$zip_url" "$zip_file"; then
        error "Failed to download jd CLI"
        exit 1
    fi
    success "Downloaded successfully"

    # Extract zip
    log "Extracting files..."
    if ! unzip -q "$zip_file" -d "$tmp_dir"; then
        error "Failed to extract zip file"
        exit 1
    fi

    # Find extracted directory (it will be named jd-{version})
    local extracted_dir="${tmp_dir}/jd-${clean_version}"
    if [ ! -d "$extracted_dir" ]; then
        # Try without version number
        extracted_dir="${tmp_dir}/jd-main"
        if [ ! -d "$extracted_dir" ]; then
            error "Failed to find extracted directory"
            exit 1
        fi
    fi

    # Remove old installation if exists
    if [ -d "$INSTALL_DIR" ]; then
        log "Removing old installation..."
        rm -rf "$INSTALL_DIR"
    fi

    # Create installation directory
    log "Installing to ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"
    cp -R "$extracted_dir"/* "$INSTALL_DIR/"

    # Make scripts executable
    chmod +x "$INSTALL_DIR/bin/jd"
    chmod +x "$INSTALL_DIR/commands"/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/scripts"/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/utils"/*.sh 2>/dev/null || true

    # Create bin directory if it doesn't exist
    mkdir -p "$BIN_DIR"

    # Create symlink
    log "Creating symlink..."
    ln -sf "$INSTALL_DIR/bin/jd" "$BIN_DIR/jd"

    # Mark installation method
    echo "curl" > "$INSTALL_DIR/.install_method"

    success "Installation complete!"

    # Setup PATH
    setup_path

    # Check if jd is in PATH
    if command_exists jd; then
        success "jd CLI is ready to use!"
    else
        warning "jd is installed but not in your current PATH"
        warning "Please restart your terminal or run:"
        echo ""
        echo "  source $(get_shell_config)"
        echo ""
        warning "Or add this to your PATH manually:"
        echo ""
        echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
        echo ""
    fi

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}   Installation Complete!              ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""

    log "Installation directory: ${INSTALL_DIR}"
    log "Executable location: ${BIN_DIR}/jd"
    echo ""
    log "Run 'jd --help' to see all available commands"
    log "Run 'jd init' to complete the setup with dependencies"
    echo ""
}

# Run installation
install_jd "$@"
