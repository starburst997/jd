#!/usr/bin/env bash

# Setup script for local development and testing
# This creates a symlink so you can use 'jd' command globally during development

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Setting up jd CLI for local development..."
echo ""

# Make all scripts executable
echo "Making scripts executable..."
chmod +x "$ROOT_DIR/bin/jd"
chmod +x "$ROOT_DIR/scripts"/*.sh
chmod +x "$ROOT_DIR/commands"/*.sh

# Install npm dependencies
if [ -f "$ROOT_DIR/package.json" ]; then
    echo "Installing npm dependencies..."
    cd "$ROOT_DIR"
    npm install
fi

# Create symlink for global usage
LINK_PATH="/usr/local/bin/jd"
LINK_TARGET="$ROOT_DIR/bin/jd"

echo ""
echo "To use 'jd' command globally, we need to create a symlink."
echo "This requires sudo access."
echo ""
echo "Symlink will be created:"
echo "  $LINK_PATH -> $LINK_TARGET"
echo ""

read -p "Create symlink? [y/N]: " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove existing symlink if it exists
    if [ -L "$LINK_PATH" ]; then
        echo "Removing existing symlink..."
        sudo rm "$LINK_PATH"
    elif [ -f "$LINK_PATH" ]; then
        echo "Warning: $LINK_PATH exists and is not a symlink"
        echo "Please remove it manually and run this script again"
        exit 1
    fi

    # Create new symlink
    echo "Creating symlink..."
    sudo ln -s "$LINK_TARGET" "$LINK_PATH"

    echo ""
    echo "✓ Setup complete!"
    echo ""
    echo "You can now use 'jd' command from anywhere:"
    echo "  jd --help"
    echo "  jd dev"
    echo "  jd pr"
else
    echo ""
    echo "Skipping symlink creation."
    echo ""
    echo "To use jd CLI, you can:"
    echo "  1. Run directly: $ROOT_DIR/bin/jd"
    echo "  2. Add to PATH: export PATH=\"$ROOT_DIR/bin:\$PATH\""
    echo "  3. Create alias: alias jd='$ROOT_DIR/bin/jd'"
fi

echo ""
echo "For npm publishing:"
echo "  1. Update version in package.json"
echo "  2. npm login (if not already logged in)"
echo "  3. npm publish --access public"
echo ""