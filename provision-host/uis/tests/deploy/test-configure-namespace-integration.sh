#!/bin/bash
# test-configure-namespace-integration.sh - Integration tests for --namespace + --secret-name-prefix
#
# REQUIRES: Running K8s cluster with PostgreSQL deployed
# Run: uis deploy postgresql (before running these tests)
#
# These tests create and remove resources in the cluster:
# - Test database, user
# - Test namespace, secret

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_CLI="/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh"
else
    UIS_CLI="$(cd "$SCRIPT_DIR/../../manage" && pwd)/uis-cli.sh"
fi

TEST_TIMESTAMP=$(date +%s)
TEST_APP="ns-test-${TEST_TIMESTAMP}"
TEST_DB="${TEST_APP//-/_}_db"
TEST_USER="${TEST_APP//-/_}"
TEST_NS="ns-test-${TEST_TIMESTAMP}"
TEST_PREFIX="ns-test-${TEST_TIMESTAMP}"
TEST_SECRET_NAME="${TEST_PREFIX}-db"

print_test_section "Integration: Pre-flight"

start_test "kubectl is available"
if command -v kubectl &>/dev/null; then
    pass_test
else
    fail_test "kubectl not found"
    print_summary
    exit 1
fi

start_test "PostgreSQL is deployed"
if kubectl get pods -n default -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | grep -q Running; then
    pass_test
else
    fail_test "PostgreSQL is not running. Run: uis deploy postgresql"
    print_summary
    exit 1
fi

# ============================================================
# Test: configure with --namespace + --secret-name-prefix
# ============================================================

print_test_section "Integration: configure --namespace creates K8s Secret"

start_test "uis configure with --namespace returns secret_name in JSON"
output=$("$UIS_CLI" configure postgresql --app "$TEST_APP" --database "$TEST_DB" --namespace "$TEST_NS" --secret-name-prefix "$TEST_PREFIX" --json 2>/dev/null)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
if [[ "$status" == "ok" ]]; then
    pass_test
else
    fail_test "Expected status=ok, got: $status (output: $output)"
fi

start_test "JSON includes secret_name"
secret_name=$(echo "$output" | jq -r '.secret_name' 2>/dev/null)
if [[ "$secret_name" == "$TEST_SECRET_NAME" ]]; then
    pass_test
else
    fail_test "Expected secret_name=$TEST_SECRET_NAME, got: $secret_name"
fi

start_test "JSON includes secret_namespace"
secret_ns=$(echo "$output" | jq -r '.secret_namespace' 2>/dev/null)
if [[ "$secret_ns" == "$TEST_NS" ]]; then
    pass_test
else
    fail_test "Expected secret_namespace=$TEST_NS, got: $secret_ns"
fi

start_test "JSON includes env_var=DATABASE_URL"
env_var=$(echo "$output" | jq -r '.env_var' 2>/dev/null)
if [[ "$env_var" == "DATABASE_URL" ]]; then
    pass_test
else
    fail_test "Expected env_var=DATABASE_URL, got: $env_var"
fi

start_test "JSON still includes cluster.database_url (deprecation period)"
cluster_url=$(echo "$output" | jq -r '.cluster.database_url' 2>/dev/null)
if [[ -n "$cluster_url" && "$cluster_url" != "null" ]]; then
    pass_test
else
    fail_test "cluster.database_url missing (should still be present in deprecation period)"
fi

# ============================================================
# Test: namespace was actually created
# ============================================================

print_test_section "Integration: namespace and secret in K8s"

start_test "Namespace was created in K8s"
if kubectl get namespace "$TEST_NS" --no-headers 2>/dev/null | grep -q "$TEST_NS"; then
    pass_test
else
    fail_test "Namespace $TEST_NS not found"
fi

start_test "Secret was created in the namespace"
if kubectl get secret "$TEST_SECRET_NAME" -n "$TEST_NS" --no-headers 2>/dev/null | grep -q "$TEST_SECRET_NAME"; then
    pass_test
else
    fail_test "Secret $TEST_SECRET_NAME not found in namespace $TEST_NS"
fi

start_test "Secret has DATABASE_URL key"
secret_db_url=$(kubectl get secret "$TEST_SECRET_NAME" -n "$TEST_NS" -o jsonpath='{.data.DATABASE_URL}' 2>/dev/null | base64 -d 2>/dev/null)
if echo "$secret_db_url" | grep -q "^postgresql://"; then
    pass_test
else
    fail_test "Secret DATABASE_URL is not a valid postgresql:// URL: $secret_db_url"
fi

start_test "Secret DATABASE_URL matches cluster URL from JSON response"
expected_url=$(echo "$output" | jq -r '.cluster.database_url' 2>/dev/null)
if [[ "$secret_db_url" == "$expected_url" ]]; then
    pass_test
else
    fail_test "Mismatch: secret has '$secret_db_url' but JSON returned '$expected_url'"
fi

# ============================================================
# Test: idempotency — secret updated on re-run
# ============================================================

print_test_section "Integration: idempotent re-run updates secret"

start_test "Re-running returns already_configured with new password"
output2=$("$UIS_CLI" configure postgresql --app "$TEST_APP" --database "$TEST_DB" --namespace "$TEST_NS" --secret-name-prefix "$TEST_PREFIX" --json 2>/dev/null)
status2=$(echo "$output2" | jq -r '.status' 2>/dev/null)
if [[ "$status2" == "already_configured" ]]; then
    pass_test
else
    fail_test "Expected already_configured, got: $status2"
fi

start_test "already_configured includes secret_name (DCT contract)"
secret_name2=$(echo "$output2" | jq -r '.secret_name' 2>/dev/null)
if [[ "$secret_name2" == "$TEST_SECRET_NAME" ]]; then
    pass_test
else
    fail_test "Expected secret_name=$TEST_SECRET_NAME, got: $secret_name2"
fi

start_test "Secret was updated with new password"
new_secret_url=$(kubectl get secret "$TEST_SECRET_NAME" -n "$TEST_NS" -o jsonpath='{.data.DATABASE_URL}' 2>/dev/null | base64 -d 2>/dev/null)
new_expected_url=$(echo "$output2" | jq -r '.cluster.database_url' 2>/dev/null)
if [[ "$new_secret_url" == "$new_expected_url" ]]; then
    pass_test
else
    fail_test "Secret not updated: has '$new_secret_url', expected '$new_expected_url'"
fi

start_test "Password actually changed between runs (different from first run)"
old_pass=$(echo "$output" | jq -r '.password' 2>/dev/null)
new_pass=$(echo "$output2" | jq -r '.password' 2>/dev/null)
if [[ -n "$old_pass" && -n "$new_pass" && "$old_pass" != "$new_pass" ]]; then
    pass_test
else
    fail_test "Password not rotated: old=$old_pass, new=$new_pass"
fi

# ============================================================
# Test: backward compat — no namespace flag works as before
# ============================================================

print_test_section "Integration: backward compat — no namespace flag"

BACKCOMPAT_APP="ns-backcompat-${TEST_TIMESTAMP}"
BACKCOMPAT_DB="${BACKCOMPAT_APP//-/_}_db"

start_test "Configure without --namespace returns ok and no secret fields"
bc_output=$("$UIS_CLI" configure postgresql --app "$BACKCOMPAT_APP" --database "$BACKCOMPAT_DB" --json 2>/dev/null)
bc_status=$(echo "$bc_output" | jq -r '.status' 2>/dev/null)
bc_secret_name=$(echo "$bc_output" | jq -r '.secret_name // "absent"' 2>/dev/null)
if [[ "$bc_status" == "ok" && "$bc_secret_name" == "absent" ]]; then
    pass_test
else
    fail_test "Expected status=ok with no secret_name; got status=$bc_status secret_name=$bc_secret_name"
fi

start_test "Configure without --namespace still includes cluster.database_url"
bc_cluster=$(echo "$bc_output" | jq -r '.cluster.database_url' 2>/dev/null)
if [[ -n "$bc_cluster" && "$bc_cluster" != "null" ]]; then
    pass_test
else
    fail_test "cluster.database_url missing in backward-compat mode"
fi

# ============================================================
# Cleanup
# ============================================================

print_test_section "Integration: Cleanup"

ADMIN_PASS=$(kubectl get secret urbalurba-secrets -n default -o jsonpath='{.data.PGPASSWORD}' 2>/dev/null | base64 -d)
PG_POD=$(kubectl get pods -n default -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

start_test "Drop test databases"
kubectl exec "$PG_POD" -n default -- env PGPASSWORD="$ADMIN_PASS" psql -U postgres -c "DROP DATABASE IF EXISTS $TEST_DB" 2>/dev/null
kubectl exec "$PG_POD" -n default -- env PGPASSWORD="$ADMIN_PASS" psql -U postgres -c "DROP USER IF EXISTS $TEST_USER" 2>/dev/null
kubectl exec "$PG_POD" -n default -- env PGPASSWORD="$ADMIN_PASS" psql -U postgres -c "DROP DATABASE IF EXISTS $BACKCOMPAT_DB" 2>/dev/null
kubectl exec "$PG_POD" -n default -- env PGPASSWORD="$ADMIN_PASS" psql -U postgres -c "DROP USER IF EXISTS ${BACKCOMPAT_APP//-/_}" 2>/dev/null
pass_test

start_test "Drop test namespace (also drops the secret)"
kubectl delete namespace "$TEST_NS" --wait=false >/dev/null 2>&1 || true
pass_test

print_summary
