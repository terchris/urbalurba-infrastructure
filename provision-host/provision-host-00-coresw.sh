#!/bin/bash
# filename: provision-host-00-coresw.sh
# description: Installs core sw tools on the provision host.

# Run systemctl daemon-reload to address unit file changes
sudo systemctl daemon-reload

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Global variable for architecture
ARCHITECTURE=$(uname -m)

# Function to add status
add_status() {
    local tool=$1
    local step=$2
    local status=$3
    STATUS["$tool|$step"]=$status
}

# Function to add error
add_error() {
    local tool=$1
    local error=$2
    ERRORS["$tool"]="${ERRORS[$tool]}${ERRORS[$tool]:+$'\n'}$error"
}

# Function to check command success
check_command_success() {
    local tool=$1
    local step=$2
    if [ $? -ne 0 ]; then
        add_status "$tool" "$step" "Fail"
        add_error "$tool" "$step"
        return 1
    else
        add_status "$tool" "$step" "OK"
        return 0
    fi
}

# Function to check supported architecture
check_architecture() {
    local tool=$1
    if [[ "$ARCHITECTURE" != "x86_64" && "$ARCHITECTURE" != "aarch64" ]]; then
        add_error "$tool" "Unsupported architecture: $ARCHITECTURE"
        return 1
    fi
    return 0
}

# Install GitHub CLI
install_github_cli() {
    if command -v gh &> /dev/null; then
        GH_VERSION=$(gh --version 2>&1 | head -n1 | cut -d' ' -f3)
        add_status "GitHub CLI" "Status" "Already installed (${GH_VERSION})"
        return 0
    fi

    echo "Installing GitHub CLI"
    check_architecture "GitHub CLI" || return 1

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install gh -y
    check_command_success "GitHub CLI" "Installation" || return 1

    GH_VERSION=$(gh --version 2>&1 | head -n1 | cut -d' ' -f3)
    add_status "GitHub CLI" "Status" "Installed (${GH_VERSION})"
    return 0
}

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    sudo apt-get clean -qq
    sudo apt-get autoremove -qq -y
}

# Print summary
print_summary() {
    echo "---------- Installation Summary ----------"
    echo "System Architecture: $ARCHITECTURE"
    echo "---------------------------------------------------"

    echo "GitHub CLI: ${STATUS["GitHub CLI|Status"]:-Not installed}"

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All installations completed successfully."
    else
        echo "Errors occurred during installation:"
        for tool in "${!ERRORS[@]}"; do
            echo "  $tool: ${ERRORS[$tool]}"
        done
    fi
}

# Main execution
main() {
    echo "Starting core software tools installation on $(hostname)"
    echo "System Architecture: $ARCHITECTURE"
    echo "---------------------------------------------------"

    trap cleanup EXIT

    # Run apt update once at the beginning
    sudo apt-get update -qq
    sudo apt-get install -qq -y curl

    install_github_cli || return 1

    print_summary

    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?