#!/bin/bash
# File: .devcontainer/additions/lib/environment-utils.sh
# Purpose: Shared library for environment setup and validation
# Used by: postCreateCommand.sh, dev-env.sh
#
# This library provides common functions for setting up the devcontainer environment,
# managing PATH, creating command symlinks, and validating installed tools.
#
# Functions:
#   setup_devcontainer_path()    - Add .devcontainer to PATH
#   setup_command_symlinks()     - Create command symlinks
#   setup_git_infrastructure()   - Configure Git for container
#   check_command_version()      - Check if command exists and get version
#   validate_environment()       - Validate required tools
#   get_host_info()              - Get host system information

#------------------------------------------------------------------------------
# Dependencies Check
#------------------------------------------------------------------------------

# This library requires install-common.sh for add_to_bashrc()
if ! declare -F add_to_bashrc &>/dev/null; then
    # Try to source it
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/install-common.sh" ]]; then
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/install-common.sh"
    else
        echo "WARNING: environment-utils.sh works best with install-common.sh for PATH management" >&2
    fi
fi

#------------------------------------------------------------------------------
# PATH Management Functions
#------------------------------------------------------------------------------

# Setup PATH to include .devcontainer directory for custom commands
#
# This adds /workspace/.devcontainer to the PATH so that commands like
# dev-setup, dev-check, etc. are available without full paths.
#
# Parameters:
#   None
#
# Returns:
#   0 - Success
#
# Side Effects:
#   - Adds export to ~/.bashrc
#   - Exports PATH for current session
#
setup_devcontainer_path() {
    echo "🔗 Setting up PATH for devcontainer commands..."

    local devcontainer_path="/workspace/.devcontainer"

    # Check if add_to_bashrc is available (from install-common.sh)
    if declare -F add_to_bashrc &>/dev/null; then
        # Use library function
        add_to_bashrc \
            "export PATH=\"$devcontainer_path:\$PATH\"" \
            '# Add devcontainer commands to PATH' \
            "export PATH=\"$devcontainer_path:\$PATH\""
    else
        # Fallback: Manual .bashrc update
        if ! grep -q "export PATH=\"$devcontainer_path:" ~/.bashrc 2>/dev/null; then
            echo "" >> ~/.bashrc
            echo "# Add devcontainer commands to PATH" >> ~/.bashrc
            echo "export PATH=\"$devcontainer_path:\$PATH\"" >> ~/.bashrc
        fi
    fi

    # Export for current session
    export PATH="$devcontainer_path:$PATH"

    echo "✅ PATH configured"
    return 0
}

#------------------------------------------------------------------------------
# Command Symlink Management
#------------------------------------------------------------------------------

# Create symlinks for devcontainer commands (without .sh extension)
#
# Creates symlinks in /workspace/.devcontainer for easy command access:
#   - dev-setup         -> manage/dev-setup.sh
#   - dev-services      -> manage/dev-services.sh
#   - dev-template      -> manage/dev-template.sh
#   - dev-update        -> manage/dev-update.sh
#   - dev-check         -> manage/dev-check.sh
#   - dev-clean         -> manage/dev-clean.sh
#   - dev-env           -> manage/dev-env.sh
#   - dev-help          -> manage/dev-help.sh
#
# Parameters:
#   None
#
# Returns:
#   0 - Success (even if some symlinks already exist)
#
setup_command_symlinks() {
    echo "🔗 Setting up devcontainer command symlinks..."

    local devcontainer_dir="/workspace/.devcontainer"
    local commands=(
        "dev-setup"
        "dev-services"
        "dev-template"
        "dev-update"
        "dev-check"
        "dev-clean"
        "dev-env"
        "dev-help"
        "dev-docs"
        "dev-test"
    )

    local created=0
    local skipped=0

    for cmd in "${commands[@]}"; do
        # Check if there's a corresponding script or symlink already
        if [ -f "$devcontainer_dir/$cmd" ] || [ -L "$devcontainer_dir/$cmd" ]; then
            ((skipped++))
        else
            # Try to create symlink if source exists
            local source_script=""

            # Check in manage/ directory first
            if [ -f "$devcontainer_dir/manage/${cmd}.sh" ]; then
                source_script="manage/${cmd}.sh"
            # Check in additions/ directory
            elif [ -f "$devcontainer_dir/additions/${cmd}.sh" ]; then
                source_script="additions/${cmd}.sh"
            fi

            if [ -n "$source_script" ]; then
                ln -sf "$source_script" "$devcontainer_dir/$cmd" 2>/dev/null && ((created++))
            fi
        fi
    done

    if [ $created -gt 0 ]; then
        echo "✅ Devcontainer commands available: ${commands[*]}"
    elif [ $skipped -gt 0 ]; then
        echo "✅ Devcontainer commands available: ${commands[*]}"
    else
        echo "⚠️  Some devcontainer commands may not be available"
    fi

    return 0
}

#------------------------------------------------------------------------------
# Git Infrastructure Setup
#------------------------------------------------------------------------------

# Setup Git infrastructure for container environment
#
# NOTE: This is infrastructure setup, NOT user configuration (that's in config-git.sh)
#
# WHY THIS IS SEPARATE FROM config-git.sh:
# - Must run BEFORE any git commands (including config-git.sh which uses git)
# - These are container infrastructure settings, not personal user preferences
# - Same for all users, not personal (unlike name/email in config-git.sh)
#
# WHAT IT DOES:
# - safe.directory: Allows git to work with mounted volumes (security requirement)
# - core.fileMode: Ignores file permission changes (mounted volumes issue)
# - core.hideDotFiles: Shows dotfiles properly (cross-platform compatibility)
#
# Parameters:
#   None
#
# Returns:
#   0 - Success
#   1 - Git setup failed
#
setup_git_infrastructure() {
    # Mark workspace as safe globally (required for mounted volumes)
    git config --global --add safe.directory /workspace >/dev/null 2>&1
    git config --global --add safe.directory '*' >/dev/null 2>&1

    # Container-specific git configurations for mounted volumes
    git config --global core.fileMode false >/dev/null 2>&1      # Ignore file mode changes
    git config --global core.hideDotFiles false >/dev/null 2>&1  # Show dotfiles

    # Verify git works
    if git status &>/dev/null; then
        echo "✅ Git repository configured"
        return 0
    else
        echo "❌ Git setup failed"
        echo "   Repository owner ID: $(stat -c '%u' /workspace/.git 2>/dev/null || echo 'unknown')"
        echo "   Container user ID: $(id -u)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Version Checking Functions
#------------------------------------------------------------------------------

# Check if a command exists and get its version
#
# Parameters:
#   $1 - command_name: Name of the command to check
#   $2 - version_flag: Flag to get version (default: --version)
#
# Returns:
#   0 - Command exists
#   1 - Command not found
#
# Output:
#   Prints: ✅ command_name is installed (version: X.Y.Z)
#   Or:     ❌ command_name is not installed
#
check_command_version() {
    local command_name="$1"
    local version_flag="${2:---version}"

    echo "Checking $command_name installation..."

    if command -v "$command_name" >/dev/null 2>&1; then
        local version
        version=$("$command_name" "$version_flag" 2>&1 | head -1)
        echo "✅ $command_name is installed (version: $version)"
        return 0
    else
        echo "❌ $command_name is not installed"
        return 1
    fi
}

# Check Node.js version
#
# Returns:
#   0 - Node.js is installed
#   1 - Node.js not found
#
check_node_version() {
    check_command_version "node" "--version"
    return $?
}

# Check Python version
#
# Returns:
#   0 - Python is installed
#   1 - Python not found
#
check_python_version() {
    check_command_version "python" "--version"
    return $?
}

# Check Go version
#
# Returns:
#   0 - Go is installed
#   1 - Go not found
#
check_go_version() {
    check_command_version "go" "version"
    return $?
}

# Check Docker version
#
# Returns:
#   0 - Docker is installed
#   1 - Docker not found
#
check_docker_version() {
    check_command_version "docker" "--version"
    return $?
}

# List global npm packages
#
# Returns:
#   0 - Success
#
check_npm_packages() {
    echo "📦 Installed npm global packages:"
    if command -v npm >/dev/null 2>&1; then
        npm list -g --depth=0
        return 0
    else
        echo "   npm not available"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Environment Validation Functions
#------------------------------------------------------------------------------

# Validate that required commands are available
#
# Parameters:
#   $@ - command_names: List of required commands
#
# Returns:
#   0 - All commands available
#   1 - One or more commands missing
#
# Output:
#   Prints status for each command
#
validate_required_commands() {
    local commands=("$@")
    local missing=0

    echo "🔍 Validating required commands..."

    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "   ✅ $cmd"
        else
            echo "   ❌ $cmd (missing)"
            ((missing++))
        fi
    done

    if [ $missing -eq 0 ]; then
        echo "✅ All required commands available"
        return 0
    else
        echo "❌ $missing required command(s) missing"
        return 1
    fi
}

# Validate environment is properly set up
#
# Checks:
#   - /workspace directory exists
#   - .devcontainer directory exists
#   - Basic commands available (bash, git)
#
# Returns:
#   0 - Environment valid
#   1 - Environment has issues
#
validate_environment() {
    echo "🔍 Validating environment..."

    local errors=0

    # Check workspace directory
    if [ ! -d /workspace ]; then
        echo "❌ /workspace directory not found"
        ((errors++))
    fi

    # Check devcontainer directory
    if [ ! -d /workspace/.devcontainer ]; then
        echo "❌ /workspace/.devcontainer directory not found"
        ((errors++))
    fi

    # Check basic commands
    local required_commands=("bash" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ Required command missing: $cmd"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✅ Environment validation passed"
        return 0
    else
        echo "❌ Environment validation failed with $errors error(s)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Host Information Functions
#------------------------------------------------------------------------------

# Get host system information from secrets
#
# Returns:
#   0 - Host info available
#   1 - Host info not available
#
# Output:
#   Sets variables: HOST_OS, HOST_USER, HOST_HOSTNAME, HOST_DOMAIN, HOST_CPU_ARCH
#
get_host_info() {
    local host_info_file="/workspace/.devcontainer.secrets/env-vars/.host-info"

    if [ -f "$host_info_file" ]; then
        # shellcheck source=/dev/null
        source "$host_info_file"
        return 0
    else
        return 1
    fi
}

# Display host information
#
# Returns:
#   0 - Success
#
show_host_info() {
    if get_host_info; then
        echo "  Operating System:  $HOST_OS"
        echo "  User:              $HOST_USER"
        echo "  Hostname:          $HOST_HOSTNAME"
        [ -n "$HOST_DOMAIN" ] && echo "  Domain:            $HOST_DOMAIN" || echo "  Domain:            none"
        echo "  Architecture:      $HOST_CPU_ARCH"
        return 0
    else
        echo "  Host information not available"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Container Information Functions
#------------------------------------------------------------------------------

# Get container name
#
# Tries multiple methods to determine the container name
#
# Returns:
#   0 - Success
#
# Output:
#   Prints container name
#
get_container_name() {
    # Method 1: Try docker inspect if socket is available
    if command -v docker >/dev/null 2>&1; then
        local container_id
        container_id=$(hostname)
        local name
        name=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's/^\///')
        if [[ -n "$name" ]]; then
            echo "$name"
            return 0
        fi
    fi

    # Method 2: Parse devcontainer.json
    if [[ -f /workspace/.devcontainer/devcontainer.json ]]; then
        local name
        name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' /workspace/.devcontainer/devcontainer.json | cut -d'"' -f4)
        if [[ -n "$name" ]]; then
            # Convert to lowercase and replace spaces with hyphens (Docker container naming convention)
            name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            echo "$name"
            return 0
        fi
    fi

    # Method 3: Fallback to just container ID
    hostname
    return 0
}

# Display container information
#
# Returns:
#   0 - Success
#
show_container_info() {
    local container_name
    container_name=$(get_container_name)

    echo "  Container Name:    $container_name"
    echo "  Container ID:      $(whoami)@$(hostname)"

    if [[ -f /etc/os-release ]]; then
        local os_name
        os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        echo "  Base Image:        $os_name"
    fi

    # System resources
    local disk_info
    disk_info=$(df -h / | awk 'NR==2 {print $4 " free of " $2}')
    echo "  Disk Space:        $disk_info"
    echo "  Working Directory: $(pwd)"

    return 0
}

#------------------------------------------------------------------------------
# Docker Statistics Functions
#------------------------------------------------------------------------------

# Get Docker server statistics
#
# Returns:
#   0 - Statistics available
#   1 - Docker not available
#
# Output:
#   Prints: total=X;running=Y;stopped=Z;paused=A;images=B
#
get_docker_stats() {
    # Get Docker server statistics if Docker is available
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        local docker_info
        docker_info=$(docker info 2>/dev/null)

        # Extract statistics
        local total running stopped paused images
        total=$(echo "$docker_info" | grep "^ Containers:" | awk '{print $2}')
        running=$(echo "$docker_info" | grep "^  Running:" | awk '{print $2}')
        stopped=$(echo "$docker_info" | grep "^  Stopped:" | awk '{print $2}')
        paused=$(echo "$docker_info" | grep "^  Paused:" | awk '{print $2}')
        images=$(echo "$docker_info" | grep "^ Images:" | awk '{print $2}')

        # Only output if we got valid data
        if [[ -n "$total" ]]; then
            echo "total=$total;running=$running;stopped=$stopped;paused=$paused;images=$images"
            return 0
        fi
    fi

    return 1
}

# Display Docker statistics
#
# Returns:
#   0 - Success
#   1 - Docker not available
#
show_docker_stats() {
    local stats
    stats=$(get_docker_stats)

    if [ $? -eq 0 ]; then
        echo ""
        echo "  Docker Engine Status:"

        # Parse the stats
        local total running stopped paused images
        eval "$stats"

        echo "    Containers: $total (running: $running, stopped: $stopped, paused: $paused)"
        echo "    Images:     $images"
        return 0
    else
        echo ""
        echo "  Docker Engine: Not accessible from container"
        return 1
    fi
}
