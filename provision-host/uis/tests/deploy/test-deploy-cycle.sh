#!/bin/bash
# test-deploy-cycle.sh - Test full deploy/remove cycle
#
# WARNING: This test modifies the Kubernetes cluster!
# Only run when explicitly requested with: ./run-tests.sh deploy
#
# Tests:
# 1. Verify cluster connectivity
# 2. Deploy a test service
# 3. Verify service is running
# 4. Remove the service
# 5. Verify service is removed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
UIS_DIR="$(dirname "$TESTS_DIR")"

# Source test framework
source "$TESTS_DIR/lib/test-framework.sh"

# UIS CLI path
UIS_CLI="${UIS_CLI:-$UIS_DIR/manage/uis-cli.sh}"

# Test service - nginx is lightweight and quick to deploy
TEST_SERVICE="${TEST_SERVICE:-nginx}"

print_test_section "Deploy Cycle Tests"
echo ""
echo -e "${TEST_YELLOW}⚠  WARNING: This test modifies the Kubernetes cluster!${TEST_NC}"
echo ""
echo "Test service: $TEST_SERVICE"
echo "UIS CLI: $UIS_CLI"
echo ""

# ============================================================
# Pre-flight Checks
# ============================================================

start_test "UIS CLI exists"
if [[ -f "$UIS_CLI" && -x "$UIS_CLI" ]]; then
    pass_test
else
    fail_test "UIS CLI not found or not executable: $UIS_CLI"
    echo ""
    echo "Cannot continue without UIS CLI"
    print_summary
    exit 1
fi

start_test "Kubernetes cluster is accessible"
if kubectl cluster-info >/dev/null 2>&1; then
    pass_test
else
    skip_test "Cannot connect to Kubernetes cluster"
    echo ""
    echo "Skipping deploy tests - no cluster connection"
    echo "Ensure kubectl is configured and cluster is running"
    print_summary
    exit 0
fi

start_test "Service script exists for $TEST_SERVICE"
# Check if the service exists in UIS
if "$UIS_CLI" list 2>/dev/null | grep -q "$TEST_SERVICE"; then
    pass_test
else
    fail_test "Service '$TEST_SERVICE' not found in UIS"
    print_summary
    exit 1
fi

# ============================================================
# Deploy/Remove Cycle
# ============================================================

# Ensure clean state - remove if already deployed
start_test "Ensure clean initial state"
if "$UIS_CLI" status 2>/dev/null | grep -q "$TEST_SERVICE.*Running\|$TEST_SERVICE.*✅"; then
    echo "  Removing existing deployment..."
    "$UIS_CLI" remove "$TEST_SERVICE" 2>/dev/null || true
    sleep 5
fi
pass_test

# Deploy service
start_test "Deploy $TEST_SERVICE"
if "$UIS_CLI" deploy "$TEST_SERVICE" 2>&1; then
    pass_test
else
    fail_test "Deploy command failed"
fi

# Wait for deployment to stabilize
echo "  Waiting for deployment to stabilize..."
sleep 15

# Verify service shows as deployed
start_test "Service shows as deployed after deploy"
status=$("$UIS_CLI" status 2>&1)
if echo "$status" | grep -q "$TEST_SERVICE"; then
    if echo "$status" | grep -q "✅\|Healthy\|Running"; then
        pass_test
    else
        fail_test "Service deployed but not healthy"
        echo "Status output:"
        echo "$status"
    fi
else
    fail_test "Service not found in status output"
    echo "Status output:"
    echo "$status"
fi

# Verify pods are running (direct kubectl check)
start_test "Kubernetes pods are running"
pod_count=$(kubectl get pods -A --no-headers 2>/dev/null | grep -i "$TEST_SERVICE" | grep -c "Running" || echo 0)
if [[ "$pod_count" -gt 0 ]]; then
    pass_test "$pod_count pod(s) running"
else
    fail_test "No running pods found for $TEST_SERVICE"
fi

# Remove service
start_test "Remove $TEST_SERVICE"
if "$UIS_CLI" remove "$TEST_SERVICE" 2>&1; then
    pass_test
else
    fail_test "Remove command failed"
fi

# Wait for removal
echo "  Waiting for removal to complete..."
sleep 10

# Verify service is removed
start_test "Service removed after removal command"
status=$("$UIS_CLI" status 2>&1)
if echo "$status" | grep -q "$TEST_SERVICE.*Running\|$TEST_SERVICE.*✅"; then
    fail_test "Service still showing as running"
    echo "Status output:"
    echo "$status"
else
    pass_test
fi

# Verify pods are gone (direct kubectl check)
start_test "Kubernetes pods are removed"
pod_count=$(kubectl get pods -A --no-headers 2>/dev/null | grep -i "$TEST_SERVICE" | grep -c "Running" || echo 0)
if [[ "$pod_count" -eq 0 ]]; then
    pass_test
else
    fail_test "$pod_count pod(s) still running"
fi

# ============================================================
# Summary
# ============================================================

echo ""
print_summary
