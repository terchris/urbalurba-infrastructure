#!/bin/bash
# filename: test-tailscale-tunnel.sh
# description: Tests a Tailscale funnel using a local web server
# 
# This script tests if a Tailscale funnel is correctly configured
# by running a local web server and pointing the funnel to it.
#
# Usage: ./test-tailscale-tunnel.sh [port]

set -e

# Constants for directories and files
TEST_PORT=8000
TEST_MARKER="CLOUDFLARE-TEST-PAGE"
TEST_FOLDER="/mnt/urbalurbadisk/networking/test"
DEFAULT_PORT=${TEST_PORT}

# Function to log messages with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if required commands are available
check_requirements() {
    local missing=false
    
    if ! command -v tailscale &>/dev/null; then
        log "ERROR: tailscale command not found. Please install Tailscale first."
        missing=true
    fi
    
    if ! command -v python3 &>/dev/null; then
        log "ERROR: python3 command not found. Please install Python first."
        missing=true
    fi
    
    if [ "$missing" = "true" ]; then
        return 1
    fi
    
    return 0
}

# Kill any process using specified port
kill_port_process() {
    local port=$1
    if lsof -ti:$port &>/dev/null; then
        log "Killing process using port $port"
        lsof -ti:$port | xargs kill -9
    fi
}

# Check if test page exists
check_test_page() {
    if [ ! -f "${TEST_FOLDER}/index.html" ]; then
        log "ERROR: Test page not found at ${TEST_FOLDER}/index.html"
        log "Please make sure the test page exists before running this script."
        return 1
    fi
    
    # Check if the test page contains our marker
    if ! grep -q "${TEST_MARKER}" "${TEST_FOLDER}/index.html"; then
        log "WARNING: Test page doesn't contain the marker '${TEST_MARKER}'"
        log "Adding marker to existing page..."
        echo "<div id=\"${TEST_MARKER}\" style=\"display:none;\">Test marker present</div>" >> "${TEST_FOLDER}/index.html"
    fi
    
    log "Using existing test page at ${TEST_FOLDER}/index.html"
    return 0
}

# Main function
main() {
    log "Starting Tailscale funnel test..."
    
    # Check requirements
    if ! check_requirements; then
        log "ERROR: Missing required dependencies"
        exit 1
    fi
    
    # Check if port parameter is provided or use default
    PORT="${1:-$DEFAULT_PORT}"
    
    log "Using port: ${PORT}"
    
    # Check if test page exists
    if ! check_test_page; then
        exit 1
    fi
    
    # Kill any process using port
    kill_port_process ${PORT}
    kill_port_process ${TEST_PORT}
    
    # Start the web server
    log "Starting test web server on port ${TEST_PORT}..."
    python3 -m http.server ${TEST_PORT} --directory "${TEST_FOLDER}" &
    HTTP_PID=$!
    
    # Wait for web server to start
    log "Waiting for web server to start..."
    sleep 2
    
    # Check if web server is running and serving the test page correctly
    log "Testing web server response..."
    local server_response
    server_response=$(curl -s http://localhost:${TEST_PORT})
    
    if [ $? -ne 0 ] || [ -z "$server_response" ]; then
        log "ERROR: Web server is not responding"
        if kill -0 $HTTP_PID 2>/dev/null; then
            kill $HTTP_PID
        fi
        exit 1
    fi
    
    # Check if response contains our marker
    if ! echo "$server_response" | grep -q "${TEST_MARKER}"; then
        log "ERROR: Web server response doesn't contain the expected marker: ${TEST_MARKER}"
        log "Response (first 100 chars): ${server_response:0:100}..."
        if kill -0 $HTTP_PID 2>/dev/null; then
            kill $HTTP_PID
        fi
        exit 1
    fi
    
    log "Web server is running successfully and serving the test page with marker: ${TEST_MARKER}"
    
    # Get the device hostname from tailscale status
    log "Getting Tailscale device hostname..."
    DEVICE_HOSTNAME=$(tailscale status --self --json | grep -o '"DNSName":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$DEVICE_HOSTNAME" ]; then
        log "WARNING: Could not determine Tailscale hostname. Will use the default funnel URL."
        DEVICE_HOSTNAME="your-device.ts.net"
    else
        log "Tailscale device hostname: ${DEVICE_HOSTNAME}"
    fi
    
    # Turn off any existing funnel
    log "Turning off any existing Tailscale funnel..."
    sudo tailscale funnel off || true
    
    # Enable the funnel
    log "Enabling Tailscale funnel for local port ${TEST_PORT}..."
    sudo tailscale funnel ${TEST_PORT}
    
    # Get funnel status to show configuration
    log "Tailscale funnel configuration:"
    sudo tailscale funnel status || true
    
    # Display test information
    log "Test setup complete. Your funnel is now active."
    log "To test your funnel, visit: https://${DEVICE_HOSTNAME}/"
    log "The test web server will continue running until you press CTRL+C"
    
    # Wait for CTRL+C
    log "Press CTRL+C to stop the test server and funnel..."
    
    # A simple trap to handle CTRL+C gracefully
    trap cleanup INT
    
    function cleanup() {
        log "Stopping test... Cleaning up..."
        if kill -0 $HTTP_PID 2>/dev/null; then
            kill $HTTP_PID
        fi
        sudo tailscale funnel off
        log "Tailscale funnel has been disabled."
        exit 0
    }
    
    # Wait for the HTTP process to finish (or CTRL+C)
    wait $HTTP_PID
    
    # This point will only be reached if the HTTP server exits on its own
    log "Test server was stopped. Cleaning up..."
    sudo tailscale funnel off
    log "Tailscale funnel has been disabled."
    
    exit 0
}

# Run the main function with all arguments
main "$@"