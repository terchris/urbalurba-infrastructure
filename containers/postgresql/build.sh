#!/bin/bash
# Filename: containers/postgresql/build.sh
# Local build script for Urbalurba PostgreSQL container
# Supports both single-arch and multi-arch builds

set -e

# Configuration
IMAGE_NAME="ghcr.io/terchris/urbalurba-postgresql"
VERSION=${VERSION:-"latest"}
PUSH=${PUSH:-"false"}
PLATFORM=${PLATFORM:-"linux/amd64,linux/arm64"}
BUILD_SINGLE_ARCH=${BUILD_SINGLE_ARCH:-"false"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if [ "$BUILD_SINGLE_ARCH" != "true" ]; then
        if ! docker buildx version &> /dev/null; then
            log_error "Docker BuildX is not available"
            log_info "Enable BuildX or set BUILD_SINGLE_ARCH=true for single-arch build"
            exit 1
        fi

        # Check if buildx instance exists
        if ! docker buildx inspect urbalurba-builder &> /dev/null; then
            log_info "Creating buildx instance for multi-arch builds..."
            docker buildx create --name urbalurba-builder --use --bootstrap
        else
            docker buildx use urbalurba-builder
        fi
    fi

    log_success "Prerequisites check passed"
}

# Build function
build_image() {
    local dockerfile_path="$(dirname "$0")/Dockerfile"
    local context_path="$(dirname "$0")"
    
    log_info "Building PostgreSQL container..."
    log_info "Image: ${IMAGE_NAME}:${VERSION}"
    log_info "Context: ${context_path}"
    
    if [ "$BUILD_SINGLE_ARCH" = "true" ]; then
        log_info "Building single architecture image..."
        docker build \
            --file "${dockerfile_path}" \
            --tag "${IMAGE_NAME}:${VERSION}" \
            --tag "${IMAGE_NAME}:latest" \
            "${context_path}"
    else
        log_info "Building multi-architecture image for: ${PLATFORM}"
        local build_args=(
            "buildx" "build"
            "--file" "${dockerfile_path}"
            "--platform" "${PLATFORM}"
            "--tag" "${IMAGE_NAME}:${VERSION}"
            "--tag" "${IMAGE_NAME}:latest"
        )
        
        if [ "$PUSH" = "true" ]; then
            build_args+=("--push")
            log_info "Will push to registry after build"
        else
            build_args+=("--load")
            log_warning "Multi-arch images will only be available in buildx cache"
            log_warning "Set PUSH=true to push to registry for multi-arch support"
        fi
        
        build_args+=("${context_path}")
        
        docker "${build_args[@]}"
    fi
    
    log_success "Build completed successfully"
}

# Test function
test_image() {
    log_info "Testing the built image..."
    
    # Use single-arch image for testing
    local test_image="${IMAGE_NAME}:${VERSION}"
    if [ "$BUILD_SINGLE_ARCH" != "true" ] && [ "$PUSH" != "true" ]; then
        log_warning "Cannot test multi-arch image locally without pushing"
        log_info "Set BUILD_SINGLE_ARCH=true for local testing"
        return 0
    fi
    
    # Clean up any existing test container
    if docker ps -a --filter "name=urbalurba-postgres-test" --format "{{.Names}}" | grep -q "urbalurba-postgres-test"; then
        log_info "Cleaning up existing test container..."
        docker stop urbalurba-postgres-test 2>/dev/null || true
        docker rm urbalurba-postgres-test 2>/dev/null || true
    fi
    
    # Start test container
    log_info "Starting test container..."
    docker run -d \
        --name urbalurba-postgres-test \
        -e POSTGRESQL_POSTGRES_PASSWORD=testpass123 \
        -e POSTGRESQL_DATABASE=testdb \
        -p 15432:5432 \
        "${test_image}" > /dev/null

    # Check if container started successfully
    sleep 5
    for i in {1..10}; do
        if docker ps --filter "name=urbalurba-postgres-test" --format "{{.Names}}" | grep -q urbalurba-postgres-test; then
            log_success "Container started successfully"
            break
        elif [ $i -eq 10 ]; then
            log_error "Container failed to start. Checking logs:"
            docker logs urbalurba-postgres-test
            exit 1
        else
            log_info "Waiting for container to start... (attempt $i/10)"
            sleep 2
        fi
    done

    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec urbalurba-postgres-test pg_isready -U postgres &> /dev/null; then
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "PostgreSQL failed to start within timeout"
        docker logs urbalurba-postgres-test
        docker stop urbalurba-postgres-test
        exit 1
    fi
    
    log_success "PostgreSQL is ready"
    
    # Test extensions
    log_info "Testing extensions..."
    
    # Test extension availability
    docker exec -e PGPASSWORD=testpass123 urbalurba-postgres-test psql -U postgres -d testdb -c "
        CREATE EXTENSION IF NOT EXISTS vector;
        CREATE EXTENSION IF NOT EXISTS hstore;
        CREATE EXTENSION IF NOT EXISTS ltree;
        CREATE EXTENSION IF NOT EXISTS postgis;
        CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
        CREATE EXTENSION IF NOT EXISTS pg_trgm;
        CREATE EXTENSION IF NOT EXISTS btree_gin;
        CREATE EXTENSION IF NOT EXISTS pgcrypto;
    " > /dev/null
    
    # Verify extensions
    local extensions=$(docker exec -e PGPASSWORD=testpass123 urbalurba-postgres-test psql -U postgres -d testdb -t -c "
        SELECT string_agg(extname, ', ' ORDER BY extname) 
        FROM pg_extension 
        WHERE extname IN ('vector', 'hstore', 'ltree', 'postgis', 'uuid-ossp', 'pg_trgm', 'btree_gin', 'pgcrypto');
    " | tr -d ' ')
    
    log_success "Extensions installed: ${extensions}"
    
    # Test basic functionality
    log_info "Testing basic functionality..."
    docker exec -e PGPASSWORD=testpass123 urbalurba-postgres-test psql -U postgres -d testdb -c "
        -- Test vector
        CREATE TABLE test_vectors (id SERIAL, embedding vector(3));
        INSERT INTO test_vectors (embedding) VALUES ('[1,2,3]');
        
        -- Test hstore
        CREATE TABLE test_hstore (id SERIAL, data hstore);
        INSERT INTO test_hstore (data) VALUES ('key1=>value1,key2=>value2');
        
        -- Test ltree
        CREATE TABLE test_ltree (id SERIAL, path ltree);
        INSERT INTO test_ltree (path) VALUES ('root.branch.leaf');
        
        -- Test PostGIS
        CREATE TABLE test_postgis (id SERIAL, geom GEOMETRY);
        INSERT INTO test_postgis (geom) VALUES (ST_Point(1, 1));
        
        -- Test UUID
        SELECT uuid_generate_v4();
    " > /dev/null
    
    # Cleanup
    log_info "Cleaning up test container..."
    docker stop urbalurba-postgres-test > /dev/null 2>&1 || true
    docker rm urbalurba-postgres-test > /dev/null 2>&1 || true
    
    log_success "All tests passed!"
}

# Main execution
main() {
    echo "🐘 Urbalurba PostgreSQL Container Build Script"
    echo "============================================="
    
    check_prerequisites
    build_image
    
    if [ "$PUSH" != "true" ]; then
        test_image
    else
        log_info "Skipping local tests (image was pushed to registry)"
    fi
    
    echo ""
    log_success "Build process completed successfully!"
    
    if [ "$PUSH" = "true" ]; then
        echo ""
        echo "📋 Image published to registry:"
        echo "  • ${IMAGE_NAME}:${VERSION}"
        echo ""
        echo "🔧 Ready for deployment:"
        echo "  • Update Kubernetes manifests to use: ${IMAGE_NAME}:${VERSION}"
        echo "  • K8s manifest: image: ${IMAGE_NAME}:${VERSION}"
    else
        echo ""
        echo "📦 Local image built successfully"
        echo "  • Run locally: docker run -d -e POSTGRESQL_POSTGRES_PASSWORD=yourpass -p 5432:5432 ${IMAGE_NAME}:${VERSION}"
    fi
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH="true"
            shift
            ;;
        --single-arch)
            BUILD_SINGLE_ARCH="true"
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --push              Push to registry (required for multi-arch)"
            echo "  --single-arch       Build single architecture only"
            echo "  --version VERSION   Set image version (default: latest)"
            echo "  --platform PLATFORM Set target platforms (default: linux/amd64,linux/arm64)"
            echo "  --help              Show this help"
            echo ""
            echo "Environment variables:"
            echo "  VERSION             Image version tag"
            echo "  PUSH                Push to registry (true/false)"
            echo "  BUILD_SINGLE_ARCH   Build single arch only (true/false)"
            echo "  PLATFORM            Target platforms"
            echo ""
            echo "Examples:"
            echo "  $0                           # Build multi-arch, don't push"
            echo "  $0 --single-arch            # Build for current arch only"
            echo "  $0 --push --version v1.0.0  # Build and push version v1.0.0"
            echo "  VERSION=v1.0.0 PUSH=true $0 # Same as above using env vars"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
