#!/bin/bash
# filename: provision-host-03-net.sh
# description: Installs network-related software on the provision host.
#
# This script installs various networking tools including:
# - Cloudflared (Cloudflare Tunnel client)
# - Tailscale (VPN mesh networking)
# - Other networking utilities
#
# Note: Tailscale is only installed here, not configured or started.
# Configuration happens later via tailscale/802-tailscale-host-setup.sh

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

# Check if running in a container
is_container() {
    # Check for container-specific indicators
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        return 0  # True, is a container
    fi
    return 1  # False, not a container
}

# Install Cloudflared
install_cloudflared() {
    if command -v cloudflared &> /dev/null; then
        CLOUDFLARED_VERSION=$(cloudflared --version 2>&1 | grep -oP 'version \K[0-9.]+')
        add_status "Cloudflared" "Status" "Already installed (v${CLOUDFLARED_VERSION})"
        return 0
    fi

    echo "Installing Cloudflared"
    check_architecture "Cloudflared" || return 1
    
    if [ "$ARCHITECTURE" = "x86_64" ]; then
        ARCH_NAME="amd64"
    elif [ "$ARCHITECTURE" = "aarch64" ]; then
        ARCH_NAME="arm64"
    else
        add_error "Cloudflared" "Unsupported architecture: $ARCHITECTURE"
        return 1
    fi

    # Fetch latest release
    LATEST_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    if [ -z "$LATEST_VERSION" ]; then
        add_error "Cloudflared" "Failed to retrieve latest version"
        return 1
    fi

    # Download and install based on architecture
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/download/${LATEST_VERSION}/cloudflared-linux-${ARCH_NAME}"
    curl -L -o cloudflared "${CLOUDFLARED_URL}" || {
        add_error "Cloudflared" "Failed to download cloudflared"
        return 1
    }
    
    chmod +x cloudflared || {
        add_error "Cloudflared" "Failed to make cloudflared executable"
        return 1
    }
    
    sudo mv cloudflared /usr/local/bin/ || {
        add_error "Cloudflared" "Failed to move cloudflared to /usr/local/bin/"
        return 1
    }

    CLOUDFLARED_VERSION=$(cloudflared --version 2>&1 | grep -oP 'version \K[0-9.]+')
    add_status "Cloudflared" "Status" "Installed (v${CLOUDFLARED_VERSION})"
    return 0
}

# Install Tailscale
install_tailscale() {
    if command -v tailscale &> /dev/null; then
        TAILSCALE_VERSION=$(tailscale version 2>&1)
        add_status "Tailscale" "Status" "Already installed (${TAILSCALE_VERSION})"
        return 0
    fi

    echo "Installing Tailscale"
    
    # Use the official Tailscale install script
    curl -fsSL https://tailscale.com/install.sh | sudo sh || {
        add_error "Tailscale" "Failed to install Tailscale"
        return 1
    }
    
    # Don't start the service yet - this will be done later after getting the auth key
    # Just verify installation succeeded
    if ! command -v tailscale &> /dev/null; then
        add_error "Tailscale" "Installation verification failed"
        return 1
    fi
    
    # Configure IP forwarding for Linux (not needed in container)
    if ! is_container; then
        echo "Configuring IP forwarding for Tailscale"
        echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
        echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
        sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
    fi
    
    TAILSCALE_VERSION=$(tailscale version 2>&1)
    add_status "Tailscale" "Status" "Installed (${TAILSCALE_VERSION})"
    return 0
}

# Install common networking tools
install_network_tools() {
    echo "Installing common networking tools"
    
    # Check which tools are needed
    local TOOLS_TO_INSTALL=()
    
    if ! command -v dig &> /dev/null; then
        TOOLS_TO_INSTALL+=(dnsutils)
    fi
    
    if ! command -v nc &> /dev/null; then
        TOOLS_TO_INSTALL+=(netcat)
    fi
    
    if ! command -v nmap &> /dev/null; then
        TOOLS_TO_INSTALL+=(nmap)
    fi
    
    if ! command -v tcpdump &> /dev/null; then
        TOOLS_TO_INSTALL+=(tcpdump)
    fi
    
    if ! command -v traceroute &> /dev/null; then
        TOOLS_TO_INSTALL+=(traceroute)
    fi
    
    if ! command -v whois &> /dev/null; then
        TOOLS_TO_INSTALL+=(whois)
    fi
    
    if [ ${#TOOLS_TO_INSTALL[@]} -eq 0 ]; then
        add_status "Network Tools" "Status" "Already installed"
        return 0
    fi
    
    # Install missing tools
    sudo apt-get update -qq || return 1
    sudo apt-get install -qq -y "${TOOLS_TO_INSTALL[@]}" || {
        add_error "Network Tools" "Failed to install some networking tools"
        return 1
    }
    
    add_status "Network Tools" "Status" "Installed"
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

    for tool in "Cloudflared" "Tailscale" "Network Tools"; do
        echo "$tool: ${STATUS[$tool|Status]:-Not installed}"
    done

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
    echo "Starting network tools installation on $(hostname)"
    echo "System Architecture: ${ARCHITECTURE}"
    echo "---------------------------------------------------"

    trap cleanup EXIT

    # Run apt update once at the beginning
    sudo apt-get update -qq || return 1
    sudo apt-get install -qq -y curl apt-transport-https ca-certificates || return 1

    # Check if we're running in a container
    if is_container; then
        echo "Running in container environment"
    else
        echo "Running in non-container environment"
    fi

    # Install all networking components
    install_cloudflared || echo "Cloudflared installation failed but continuing"
    install_tailscale || echo "Tailscale installation failed but continuing"
    install_network_tools || echo "Network tools installation failed but continuing"

    print_summary

    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?