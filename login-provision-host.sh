#!/bin/bash
# filename: login-provision-host.sh
# description: login to the provision-host container so that you can run commands on the host
# type exit to get back to the local machine

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if the provision-host container exists
if ! docker ps -a --format "table {{.Names}}" | grep -q "^provision-host$"; then
    print_error "Container 'provision-host' not found."
    print_status "Available containers:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

# Check if the container is running
if ! docker ps --format "table {{.Names}}" | grep -q "^provision-host$"; then
    print_warning "Container 'provision-host' exists but is not running."
    print_status "Starting container..."
    if docker start provision-host; then
        print_status "Container started successfully."
    else
        print_error "Failed to start container."
        exit 1
    fi
fi

print_status "Logging into provision-host container..."
print_status "Type 'exit' to return to your local machine"
echo

docker exec -it provision-host bash