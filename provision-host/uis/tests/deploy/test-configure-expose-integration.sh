#!/bin/bash
# test-configure-expose-integration.sh - Integration tests for uis configure and uis expose
#
# REQUIRES: Running K8s cluster with PostgreSQL deployed
# Run: uis deploy postgresql (before running these tests)
#
# These tests CREATE and REMOVE resources in the cluster:
# - Creates test database and user in PostgreSQL
# - Starts and stops port-forward processes
#
# Usage:
#   ./test-configure-expose-integration.sh
#
# Can also be called by DCT via uis-bridge to verify integration:
#   docker exec uis-provision-host bash /mnt/urbalurbadisk/provision-host/uis/tests/deploy/test-configure-expose-integration.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine paths
if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_CLI="/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh"
else
    UIS_CLI="$(cd "$SCRIPT_DIR/../../manage" && pwd)/uis-cli.sh"
fi

# Test app name (unique to avoid conflicts)
TEST_APP="uis-test-$(date +%s)"
TEST_DB="${TEST_APP//-/_}_db"
TEST_USER="${TEST_APP//-/_}"

print_test_section "Integration: Pre-flight checks"

# ============================================================
# Pre-flight: cluster and PostgreSQL must be available
# ============================================================

start_test "kubectl is available"
if command -v kubectl &>/dev/null; then
    pass_test
else
    fail_test "kubectl not found — cannot run integration tests"
    print_summary
    exit 1
fi

start_test "K8s cluster is reachable"
if kubectl cluster-info &>/dev/null; then
    pass_test
else
    fail_test "Cannot reach K8s cluster — cannot run integration tests"
    print_summary
    exit 1
fi

start_test "PostgreSQL is deployed"
if kubectl get pods -n default -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | grep -q Running; then
    pass_test
else
    fail_test "PostgreSQL is not running. Deploy it first: uis deploy postgresql"
    print_summary
    exit 1
fi

# ============================================================
# Test: uis configure — non-configurable service
# ============================================================

print_test_section "Integration: uis configure — error cases"

start_test "uis configure grafana returns error (not configurable)"
output=$("$UIS_CLI" configure grafana --app test --json 2>/dev/null || true)
if echo "$output" | jq -e '.status == "error"' &>/dev/null; then
    pass_test
else
    fail_test "Expected JSON error, got: $output"
fi

start_test "Error includes phase: deploy_check"
phase=$(echo "$output" | jq -r '.phase' 2>/dev/null)
if [[ "$phase" == "deploy_check" ]]; then
    pass_test
else
    fail_test "Expected phase=deploy_check, got: $phase"
fi

start_test "uis configure postgresql without --app returns error"
output=$("$UIS_CLI" configure postgresql --json 2>&1 || true)
if echo "$output" | grep -qi "missing\|usage\|app"; then
    pass_test
else
    fail_test "Expected missing --app error, got: $output"
fi

# ============================================================
# Test: uis configure postgresql — create database
# ============================================================

print_test_section "Integration: uis configure postgresql — create"

start_test "uis configure postgresql creates database and returns JSON"
output=$("$UIS_CLI" configure postgresql --app "$TEST_APP" --database "$TEST_DB" --json 2>/dev/null)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
if [[ "$status" == "ok" ]]; then
    pass_test
else
    fail_test "Expected status=ok, got: $status (output: $output)"
fi

start_test "JSON contains local connection details"
local_host=$(echo "$output" | jq -r '.local.host' 2>/dev/null)
if [[ "$local_host" == "host.docker.internal" ]]; then
    pass_test
else
    fail_test "Expected local.host=host.docker.internal, got: $local_host"
fi

start_test "JSON contains cluster connection details"
cluster_host=$(echo "$output" | jq -r '.cluster.host' 2>/dev/null)
if [[ "$cluster_host" == "postgresql.default.svc.cluster.local" ]]; then
    pass_test
else
    fail_test "Expected cluster.host=postgresql.default.svc.cluster.local, got: $cluster_host"
fi

start_test "JSON contains database name"
db=$(echo "$output" | jq -r '.database' 2>/dev/null)
if [[ "$db" == "$TEST_DB" ]]; then
    pass_test
else
    fail_test "Expected database=$TEST_DB, got: $db"
fi

start_test "JSON contains username"
user=$(echo "$output" | jq -r '.username' 2>/dev/null)
if [[ "$user" == "$TEST_USER" ]]; then
    pass_test
else
    fail_test "Expected username=$TEST_USER, got: $user"
fi

start_test "JSON contains non-empty password"
pass=$(echo "$output" | jq -r '.password' 2>/dev/null)
if [[ -n "$pass" && "$pass" != "null" ]]; then
    pass_test
else
    fail_test "Expected non-empty password"
fi

start_test "JSON contains local.database_url"
local_url=$(echo "$output" | jq -r '.local.database_url' 2>/dev/null)
if echo "$local_url" | grep -q "postgresql://"; then
    pass_test
else
    fail_test "Expected postgresql:// URL, got: $local_url"
fi

start_test "JSON contains local.port (exposePort)"
local_port=$(echo "$output" | jq -r '.local.port' 2>/dev/null)
if [[ "$local_port" == "35432" ]]; then
    pass_test
else
    fail_test "Expected local.port=35432, got: $local_port"
fi

# ============================================================
# Test: uis configure postgresql — idempotency
# ============================================================

print_test_section "Integration: uis configure postgresql — idempotency"

start_test "Second run returns already_configured"
output2=$("$UIS_CLI" configure postgresql --app "$TEST_APP" --database "$TEST_DB" --json 2>/dev/null)
status2=$(echo "$output2" | jq -r '.status' 2>/dev/null)
if [[ "$status2" == "already_configured" ]]; then
    pass_test
else
    fail_test "Expected status=already_configured, got: $status2"
fi

# ============================================================
# Test: uis configure postgresql — init file
# ============================================================

print_test_section "Integration: uis configure postgresql — init file"

# Create a new app for init file test (the first one is already configured)
INIT_APP="uis-init-test-$(date +%s)"
INIT_DB="${INIT_APP//-/_}_db"

start_test "uis configure with init file applies SQL"
init_output=$(echo "CREATE TABLE IF NOT EXISTS test_init (id SERIAL PRIMARY KEY, name TEXT);" | \
    "$UIS_CLI" configure postgresql --app "$INIT_APP" --database "$INIT_DB" --init-file - --json 2>/dev/null)
init_status=$(echo "$init_output" | jq -r '.status' 2>/dev/null)
if [[ "$init_status" == "ok" ]]; then
    pass_test
else
    fail_test "Expected status=ok, got: $init_status (output: $init_output)"
fi

# Verify the table was created by querying it
start_test "Init file SQL was applied (table exists)"
init_pass=$(echo "$init_output" | jq -r '.password' 2>/dev/null)
init_user="${INIT_APP//-/_}"
pod=$(kubectl get pods -n default -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
table_check=$(kubectl exec "$pod" -n default -- env PGPASSWORD="$init_pass" psql -U "$init_user" -d "$INIT_DB" -t -A -c "SELECT COUNT(*) FROM test_init" 2>/dev/null)
if [[ "$table_check" == "0" ]]; then
    pass_test
else
    fail_test "Expected table test_init to exist with 0 rows, got: $table_check"
fi

# ============================================================
# Test: uis expose
# ============================================================

print_test_section "Integration: uis expose"

start_test "uis expose postgresql starts port-forward"
"$UIS_CLI" expose postgresql 2>/dev/null
sleep 2
status_output=$("$UIS_CLI" expose --status 2>/dev/null)
if echo "$status_output" | grep -q "postgresql"; then
    pass_test
else
    fail_test "postgresql not shown in expose status"
fi

start_test "Port 35432 is listening"
if ss -tlnp 2>/dev/null | grep -q ":35432 " || netstat -tlnp 2>/dev/null | grep -q ":35432 "; then
    pass_test
else
    fail_test "Port 35432 is not listening"
fi

start_test "uis expose postgresql --stop stops port-forward"
"$UIS_CLI" expose postgresql --stop 2>/dev/null
sleep 1
status_output=$("$UIS_CLI" expose --status 2>/dev/null)
if echo "$status_output" | grep -q "(none)"; then
    pass_test
else
    fail_test "postgresql still shown in expose status after stop"
fi

start_test "uis expose (idempotent) — exposing twice is OK"
"$UIS_CLI" expose postgresql 2>/dev/null
sleep 1
output=$("$UIS_CLI" expose postgresql 2>&1 || true)
if echo "$output" | grep -q "already exposed"; then
    pass_test
else
    fail_test "Expected 'already exposed' message"
fi
# Clean up
"$UIS_CLI" expose postgresql --stop 2>/dev/null

# ============================================================
# Cleanup: drop test databases
# ============================================================

print_test_section "Integration: Cleanup"

# Get admin password for cleanup
ADMIN_PASS=$(kubectl get secret urbalurba-secrets -n default -o jsonpath='{.data.PGPASSWORD}' 2>/dev/null | base64 -d)
PG_POD=$(kubectl get pods -n default -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

for db in "$TEST_DB" "$INIT_DB"; do
    user="${db%_db}"
    start_test "Drop test database: $db"
    kubectl exec "$PG_POD" -n default -- env PGPASSWORD="$ADMIN_PASS" psql -U postgres -c "DROP DATABASE IF EXISTS $db" 2>/dev/null
    kubectl exec "$PG_POD" -n default -- env PGPASSWORD="$ADMIN_PASS" psql -U postgres -c "DROP USER IF EXISTS $user" 2>/dev/null
    pass_test
done

# ============================================================
# Summary
# ============================================================

print_summary
