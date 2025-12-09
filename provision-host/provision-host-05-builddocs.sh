#!/bin/bash
# filename: provision-host-05-builddocs.sh
# description: Builds MkDocs documentation and places it in testdata/docs for nginx serving

set -e

# Directories
URBALURBA_ROOT="/mnt/urbalurbadisk"
DOCS_SOURCE="${URBALURBA_ROOT}/docs"
MKDOCS_CONFIG="${URBALURBA_ROOT}/mkdocs.yml"
DOCS_OUTPUT="${URBALURBA_ROOT}/testdata/docs"

# Initialize status tracking
declare -A STATUS
declare -A ERRORS

# Function to add status
add_status() {
    local step=$1
    local status=$2
    STATUS["$step"]=$status
}

# Function to add error
add_error() {
    local step=$1
    local error=$2
    ERRORS["$step"]="${ERRORS[$step]}${ERRORS[$step]:+$'\n'}$error"
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites for documentation build..."

    if ! command -v mkdocs &> /dev/null; then
        add_error "Prerequisites" "mkdocs not found. Run provision-host-00-coresw.sh first."
        return 1
    fi

    if [ ! -f "${MKDOCS_CONFIG}" ]; then
        add_error "Prerequisites" "mkdocs.yml not found at ${MKDOCS_CONFIG}"
        return 1
    fi

    if [ ! -d "${DOCS_SOURCE}" ]; then
        add_error "Prerequisites" "docs directory not found at ${DOCS_SOURCE}"
        return 1
    fi

    add_status "Prerequisites" "OK"
    return 0
}

# Build documentation
build_docs() {
    echo "Building MkDocs documentation..."

    # Create output directory if it doesn't exist
    mkdir -p "${DOCS_OUTPUT}"

    # Change to project root for mkdocs build
    cd "${URBALURBA_ROOT}"

    # Build documentation to testdata/docs
    if mkdocs build --site-dir "${DOCS_OUTPUT}" --clean; then
        add_status "Build" "OK"
        echo "Documentation built successfully to ${DOCS_OUTPUT}"
        return 0
    else
        add_error "Build" "mkdocs build failed"
        return 1
    fi
}

# Verify build output
verify_build() {
    echo "Verifying documentation build..."

    if [ -f "${DOCS_OUTPUT}/index.html" ]; then
        local file_count
        file_count=$(find "${DOCS_OUTPUT}" -type f | wc -l)
        add_status "Verification" "OK (${file_count} files)"
        echo "Documentation verified: ${file_count} files generated"
        return 0
    else
        add_error "Verification" "index.html not found in output directory"
        return 1
    fi
}

# Print summary
print_summary() {
    echo "---------- Documentation Build Summary ----------"
    echo "Source: ${DOCS_SOURCE}"
    echo "Config: ${MKDOCS_CONFIG}"
    echo "Output: ${DOCS_OUTPUT}"
    echo "-------------------------------------------------"

    for step in "Prerequisites" "Build" "Verification"; do
        if [ -n "${STATUS[$step]}" ]; then
            echo "$step: ${STATUS[$step]}"
        fi
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "Documentation build completed successfully."
        echo ""
        echo "The documentation will be available at /docs/ after nginx deployment."
        echo "Run the 020-setup-nginx.yml playbook to deploy to the cluster."
    else
        echo "Errors occurred during documentation build:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        return 1
    fi
}

# Main execution
main() {
    echo "Starting documentation build on $(hostname)"
    echo "---------------------------------------------------"

    local overall_exit_code=0

    check_prerequisites || overall_exit_code=1

    if [ $overall_exit_code -eq 0 ]; then
        build_docs || overall_exit_code=1
    fi

    if [ $overall_exit_code -eq 0 ]; then
        verify_build || overall_exit_code=1
    fi

    print_summary

    return $overall_exit_code
}

# Run the main function and exit with its return code
main
exit $?
