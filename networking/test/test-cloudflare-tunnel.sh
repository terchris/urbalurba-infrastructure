#!/bin/bash
# filename: test-cloudflare-tunnel.sh
# description: Tests a Cloudflare tunnel using a local web server
# 
# This script tests if a Cloudflare tunnel is correctly configured
# by running a local web server and pointing the tunnel to it.
#
# Usage: ./test-cloudflare-tunnel.sh <tunnel_name>

set -e

# Constants for directories and files
TEST_PORT=8000
TEST_MARKER="CLOUDFLARE-TEST-PAGE"
CLOUDFLARE_FOLDER="/mnt/urbalurbadisk/topsecret/cloudflare"
TEST_FOLDER="/mnt/urbalurbadisk/networking/test"
CERT_FILE="${CLOUDFLARE_FOLDER}/cloudflare-certificate.pem"

# Function to log messages with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if required commands are available
check_requirements() {
    local missing=false
    
    if ! command -v cloudflared &>/dev/null; then
        log "ERROR: cloudflared command not found. Please install Cloudflare tunnel first."
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

# Find available tunnels
list_available_tunnels() {
    log "Available tunnels:"
    cloudflared --origincert="${CERT_FILE}" tunnel list | grep -v "^ID\|^--\|^You can obtain" | awk '{print "  - " $2}'
}

# Kill any process using specified port
kill_port_process() {
    local port=$1
    if lsof -ti:$port &>/dev/null; then
        log "Killing process using port $port"
        lsof -ti:$port | xargs kill -9
    fi
}

# Main function
main() {
    log "Starting Cloudflare tunnel test..."
    
    # Check requirements
    if ! check_requirements; then
        log "ERROR: Missing required dependencies"
        exit 1
    fi
    
    # Check if tunnel name parameter is provided
    if [ -z "$1" ]; then
        log "ERROR: Tunnel name not provided"
        log "Usage: $0 <tunnel_name>"
        exit 1
    fi
    
    TUNNEL_NAME="$1"
    TUNNEL_TEST_CONFIG="${TEST_FOLDER}/cloudflare-${TUNNEL_NAME}-test-config.yml"
    
    # Check if test page exists
    if [ ! -f "${TEST_FOLDER}/index.html" ]; then
        log "ERROR: Test page not found at ${TEST_FOLDER}/index.html"
        exit 1
    fi
    
    # Check if certificate exists
    if [ ! -f "${CERT_FILE}" ]; then
        log "ERROR: Certificate file not found: ${CERT_FILE}"
        exit 1
    fi
    
    log "Using certificate: ${CERT_FILE}"
    
    # Get the tunnel ID
    log "Getting tunnel ID..."
    TUNNEL_ID=$(cloudflared --origincert="${CERT_FILE}" tunnel list | grep "${TUNNEL_NAME}" | awk '{print $1}')
    
    if [ -z "$TUNNEL_ID" ]; then
        log "ERROR: Could not find tunnel ID for ${TUNNEL_NAME}"
        list_available_tunnels
        exit 1
    fi
    
    log "Found tunnel ID: ${TUNNEL_ID}"
    
    # Check all possible credential file paths
    CREDS_FILE=""
    POSSIBLE_PATHS=(
        "${CLOUDFLARE_FOLDER}/cloudflare-${TUNNEL_NAME}-tunnel-credentials.json"
        "${CLOUDFLARE_FOLDER}/${TUNNEL_ID}.json"
        # List existing files in the folder and pick credential files
        $(find ${CLOUDFLARE_FOLDER} -name "*.json" | grep -v "config")
    )
    
    # Try each possible path
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path" ]; then
            CREDS_FILE="$path"
            break
        fi
    done
    
    # Final check if credentials file was found
    if [ -z "${CREDS_FILE}" ] || [ ! -f "${CREDS_FILE}" ]; then
        log "ERROR: Credentials file not found. Checked multiple paths including:"
        for path in "${POSSIBLE_PATHS[@]}"; do
            log "  - $path"
        done
        log "Listed files in ${CLOUDFLARE_FOLDER}:"
        ls -la ${CLOUDFLARE_FOLDER} | while read line; do
            log "  $line"
        done
        exit 1
    fi
    
    log "Using credentials file: ${CREDS_FILE}"
    
    # Create a simple test configuration that routes all traffic to the test server
    log "Creating test configuration file..."
    cat > "${TUNNEL_TEST_CONFIG}" << EOF
tunnel: ${TUNNEL_ID}
credentials-file: ${CREDS_FILE}

ingress:
  # Route all traffic to the test web server
  - service: http://localhost:${TEST_PORT}
EOF
    
    # Validate test configuration
    log "Validating test configuration..."
    if ! cloudflared --origincert="${CERT_FILE}" tunnel --config "${TUNNEL_TEST_CONFIG}" ingress validate; then
        log "ERROR: Test configuration validation failed"
        exit 1
    fi
    
    # Kill any process using port
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
    
    # Display test information
    log "Test setup complete. Tunnel will be tested with following configuration:"
    log "  - Tunnel name: ${TUNNEL_NAME}"
    log "  - Tunnel ID: ${TUNNEL_ID}"
    log "  - Certificate: ${CERT_FILE}"
    log "  - Credentials: ${CREDS_FILE}"
    log "  - Configuration: ${TUNNEL_TEST_CONFIG}"
    log "  - Test server: http://localhost:${TEST_PORT}"
    log "  - Routing all traffic to the test server"
    
    # Start the tunnel
    log "Starting Cloudflare tunnel..."
    log "*** PRESS CTRL+C TO STOP THE TUNNEL WHEN TESTING IS COMPLETE ***"
    log ""
    
    # Run the tunnel
    cloudflared --origincert="${CERT_FILE}" tunnel --config "${TUNNEL_TEST_CONFIG}" run "${TUNNEL_NAME}"
    
    # This point will only be reached when the tunnel is stopped
    log "Tunnel was stopped. Cleaning up..."
    
    # Kill the web server
    if kill -0 $HTTP_PID 2>/dev/null; then
        kill $HTTP_PID
    fi
    
    log "Test completed. Remember to check:"
    log "1. The tunnel connected successfully to Cloudflare"
    log "2. Access your tunnel through a browser to verify it's working"
    
    exit 0
}

# Run the main function with all arguments
main "$@"