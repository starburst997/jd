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

# JD Abyss color palette (24-bit RGB colors)
ABYSS_CYAN='\033[38;2;23;187;221m'      # #17bbdd
ABYSS_BLUE='\033[38;2;97;175;255m'      # #61afff
ABYSS_PURPLE='\033[38;2;225;140;245m'   # #e18cf5
ABYSS_GREEN='\033[38;2;152;210;128m'    # #98d280
ABYSS_YELLOW='\033[38;2;255;225;105m'   # #ffe169

# Logging functions
log() {
    echo -e "${GREEN}[jd]${NC} $*"
}

error() {
    echo -e "${RED}[jd error]${NC} $*" >&2
}

# Run command and capture output, display error on failure
# Usage: run_with_error_capture "description" command args...
# Returns the command's exit code
run_with_error_capture() {
    local description="$1"
    shift

    local temp_output=$(mktemp)
    local exit_code=0

    # Run command and capture both stdout and stderr
    if ! "$@" >"$temp_output" 2>&1; then
        exit_code=$?
        error "$description"

        # Show the actual error output if it exists and is not empty
        if [ -s "$temp_output" ]; then
            echo -e "${DIM}Command output:${NC}" >&2
            cat "$temp_output" >&2
        fi
    fi

    rm -f "$temp_output"
    return $exit_code
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

# Show colorful JD banner with Abyss theme gradient (Cyan → Green)
show_banner() {
    # Only show banner if not in a pipe and stdout is a terminal
    if [ -t 1 ]; then
        # Gradient from Cyan to Green (aquatic vibes)
        echo -e "${ABYSS_CYAN}     ██╗██████╗ ${NC}"
        echo -e "${ABYSS_CYAN}     ██║██╔══██╗${NC}"
        echo -e "\033[38;2;40;198;209m     ██║██║  ██║${NC}"  # Cyan-teal blend
        echo -e "\033[38;2;69;204;180m██   ██║██║  ██║${NC}"  # Teal-green blend
        echo -e "\033[38;2;114;207;154m╚█████╔╝██████╔╝${NC}"  # Light green
        echo -e "${ABYSS_GREEN} ╚════╝ ╚═════╝ ${NC}"
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

    # Try to get from GitHub using gh CLI (most accurate)
    if command_exists gh; then
        default_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null)
        if [ -n "$default_branch" ]; then
            echo "$default_branch"
            return 0
        fi
    fi

    # Fallback: Try to get from git config
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