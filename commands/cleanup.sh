#!/usr/bin/env bash

# Show cleanup command help
show_cleanup_help() {
    cat << EOF
Usage: jd cleanup [OPTIONS]

Clean up development files and free disk space

Options:
    -p, --path <path>        Path to start cleanup from (default: ~/Projects)
    -i, --include-hidden     Include hidden directories (starting with .)
    -n, --dry-run            Show what would be deleted without actually deleting
    -s, --skip-mac-cleanup   Skip running mac-cleanup
    -h, --help               Show this help message

Description:
    Recursively removes all node_modules directories from the specified path,
    calculates the total space freed, and optionally runs mac-cleanup for
    additional system cleanup.

Examples:
    jd cleanup                     # Clean ~/Projects, skip hidden dirs
    jd cleanup --path ~/Work       # Clean ~/Work directory
    jd cleanup --include-hidden    # Include hidden directories
    jd cleanup --dry-run           # Preview what would be deleted
    jd cleanup --skip-mac-cleanup  # Skip mac-cleanup at the end
EOF
}

# Calculate directory size in bytes
get_size() {
    local path="$1"
    if command -v gdu > /dev/null 2>&1; then
        # Use GNU du if available (faster)
        gdu -sb "$path" 2>/dev/null | cut -f1
    else
        # Fall back to BSD du on macOS
        du -sk "$path" 2>/dev/null | cut -f1 | awk '{print $1 * 1024}'
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size=$bytes

    while (( $(echo "$size >= 1024" | bc -l) )) && (( unit < 4 )); do
        size=$(echo "scale=2; $size / 1024" | bc)
        ((unit++))
    done

    echo "${size}${units[$unit]}"
}

# Execute cleanup command
execute_command() {
    local path="$HOME/Projects"
    local include_hidden=false
    local dry_run=false
    local skip_mac_cleanup=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--path)
                path="$2"
                shift 2
                ;;
            -i|--include-hidden)
                include_hidden=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -s|--skip-mac-cleanup)
                skip_mac_cleanup=true
                shift
                ;;
            -h|--help)
                show_cleanup_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_cleanup_help
                exit 1
                ;;
        esac
    done

    # Expand tilde in path
    path="${path/#\~/$HOME}"

    # Check if path exists
    if [[ ! -d "$path" ]]; then
        error "Path does not exist: $path"
        exit 1
    fi

    info "Starting cleanup from: $path"
    if [[ "$dry_run" == "true" ]]; then
        warning "DRY RUN MODE - No files will be deleted"
    fi

    # Build find command based on options
    local find_cmd="find \"$path\" -type d -name node_modules"

    if [[ "$include_hidden" == "false" ]]; then
        # Exclude hidden directories
        find_cmd="find \"$path\" -type d -name node_modules ! -path '*/.*' 2>/dev/null"
    else
        find_cmd="find \"$path\" -type d -name node_modules 2>/dev/null"
    fi

    # Find all node_modules directories
    info "Searching for node_modules directories..."
    local node_modules_dirs
    node_modules_dirs=$(eval "$find_cmd")

    if [[ -z "$node_modules_dirs" ]]; then
        info "No node_modules directories found"
    else
        local total_size=0
        local count=0
        local deleted_count=0

        # Process each directory
        while IFS= read -r dir; do
            if [[ -n "$dir" ]]; then
                ((count++))
                local size
                size=$(get_size "$dir")

                if [[ -n "$size" && "$size" -gt 0 ]]; then
                    total_size=$((total_size + size))

                    # Show relative path for readability
                    local rel_path="${dir#$path/}"
                    if [[ "$rel_path" == "$dir" ]]; then
                        rel_path="${dir#$HOME/}"
                        if [[ "$rel_path" == "$dir" ]]; then
                            rel_path="$dir"
                        else
                            rel_path="~/$rel_path"
                        fi
                    fi

                    if [[ "$dry_run" == "true" ]]; then
                        echo "  Would remove: $rel_path ($(format_bytes $size))"
                    else
                        echo "  Removing: $rel_path ($(format_bytes $size))"
                        rm -rf "$dir" 2>/dev/null
                        if [[ $? -eq 0 ]]; then
                            ((deleted_count++))
                        else
                            warning "  Failed to remove: $rel_path"
                        fi
                    fi
                fi
            fi
        done <<< "$node_modules_dirs"

        echo ""
        if [[ "$dry_run" == "true" ]]; then
            info "Found $count node_modules directories"
            info "Total space that would be freed: $(format_bytes $total_size)"
        else
            info "Removed $deleted_count of $count node_modules directories"
            info "Total space freed: $(format_bytes $total_size)"
        fi
    fi

    # Run mac-cleanup if not skipped and not in dry-run mode
    if [[ "$skip_mac_cleanup" == "false" && "$dry_run" == "false" ]]; then
        echo ""
        info "Running mac-cleanup..."

        # Check if mac-cleanup is installed
        if ! command -v mac-cleanup > /dev/null 2>&1; then
            warning "mac-cleanup is not installed"
            if confirm "Would you like to install mac-cleanup?"; then
                info "Installing mac-cleanup..."
                if ! brew install mac-cleanup-py; then
                    error "Failed to install mac-cleanup"
                    exit 1
                fi
            else
                info "Skipping mac-cleanup"
                exit 0
            fi
        fi

        # Run mac-cleanup with force and no-update flags
        mac-cleanup -fn

        if [[ $? -eq 0 ]]; then
            info "mac-cleanup completed successfully"
        else
            warning "mac-cleanup completed with errors"
        fi
    fi

    if [[ "$dry_run" == "false" ]]; then
        success "Cleanup completed!"
    else
        info "Dry run completed - no changes were made"
    fi
}