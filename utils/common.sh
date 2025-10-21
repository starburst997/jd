#!/usr/bin/env bash

# Common utility functions for jd CLI

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# RGB/256 color codes for gradient effects
GRADIENT_1='\033[38;5;39m'   # Bright blue
GRADIENT_2='\033[38;5;75m'   # Light blue
GRADIENT_3='\033[38;5;111m'  # Sky blue
GRADIENT_4='\033[38;5;147m'  # Lavender
GRADIENT_5='\033[38;5;183m'  # Light purple

# Logging functions
log() {
    echo -e "${GREEN}[jd]${NC} $*"
}

error() {
    echo -e "${RED}[jd error]${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}[jd warning]${NC} $*"
}

info() {
    echo -e "${BLUE}[jd info]${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[jd debug]${NC} $*"
    fi
}

# Show colorful JD banner
show_banner() {
    # Only show banner if not in a pipe and stdout is a terminal
    if [ -t 1 ]; then
        echo -e "${GRADIENT_1}"
        echo -e "     ██╗${GRADIENT_2}██████╗ ${NC}"
        echo -e "${GRADIENT_1}     ██║${GRADIENT_2}██╔══██╗${NC}"
        echo -e "${GRADIENT_2}     ██║${GRADIENT_3}██║  ██║${NC}"
        echo -e "${GRADIENT_3}██   ██║${GRADIENT_4}██║  ██║${NC}"
        echo -e "${GRADIENT_4}╚█████╔╝${GRADIENT_5}██████╔╝${NC}"
        echo -e "${GRADIENT_5} ╚════╝ ╚═════╝ ${NC}"
        echo -e "${DIM}   Personal Dev Toolkit${NC}"
        echo ""
    fi
}

# Check if running in a git repository
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        error "Not in a git repository"
        return 1
    fi
    return 0
}

# Get current git branch
get_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Get default branch (main/master)
get_default_branch() {
    local default_branch
    # Try to get from git config
    default_branch=$(git config --get init.defaultBranch 2>/dev/null)
    if [ -z "$default_branch" ]; then
        # Check if main exists
        if git show-ref --verify --quiet refs/heads/main; then
            default_branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            default_branch="master"
        else
            # Try to get from remote
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
            if [ -z "$default_branch" ]; then
                default_branch="main"
            fi
        fi
    fi
    echo "$default_branch"
}

# Confirm action with user
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    local yn
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " yn
        yn=${yn:-y}
    else
        read -p "$prompt [y/N]: " yn
        yn=${yn:-n}
    fi

    case $yn in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Get OS type
get_os() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
        msys*|cygwin*|mingw*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}