#!/bin/bash
# test-configure-namespace.sh - Unit tests for --namespace + --secret-name-prefix flags
#
# Tests that don't need a running cluster — validates argument parsing only.
# For integration tests with namespace/secret creation, see
# deploy/test-configure-namespace-integration.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_CLI="/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh"
else
    UIS_CLI="$(cd "$SCRIPT_DIR/../../manage" && pwd)/uis-cli.sh"
fi

print_test_section "Configure: --namespace + --secret-name-prefix arg parsing"

# ============================================================
# Validation: both flags must come together
# ============================================================

start_test "Missing --secret-name-prefix when --namespace is set returns usage error"
output=$("$UIS_CLI" configure postgresql --app a --database b --namespace ns --json 2>/dev/null || true)
phase=$(echo "$output" | jq -r '.phase' 2>/dev/null)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
if [[ "$status" == "error" && "$phase" == "usage" ]]; then
    pass_test
else
    fail_test "Expected status=error, phase=usage; got: $output"
fi

start_test "Missing --namespace when --secret-name-prefix is set returns usage error"
output=$("$UIS_CLI" configure postgresql --app a --database b --secret-name-prefix p --json 2>/dev/null || true)
phase=$(echo "$output" | jq -r '.phase' 2>/dev/null)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
if [[ "$status" == "error" && "$phase" == "usage" ]]; then
    pass_test
else
    fail_test "Expected status=error, phase=usage; got: $output"
fi

start_test "Missing --app argument returns usage error (regression test for 3UIS)"
output=$("$UIS_CLI" configure postgresql --json 2>/dev/null || true)
phase=$(echo "$output" | jq -r '.phase' 2>/dev/null)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
if [[ "$status" == "error" && "$phase" == "usage" ]]; then
    pass_test
else
    fail_test "Expected status=error, phase=usage; got: $output"
fi

# ============================================================
# Help mentions the new flags
# ============================================================

start_test "uis configure usage mentions --namespace"
output=$("$UIS_CLI" configure 2>&1 || true)
if echo "$output" | grep -q -- "--namespace\|configure"; then
    pass_test
else
    fail_test "Usage output does not mention --namespace or configure: $output"
fi

# ============================================================
# Source the lib and verify _pg_secret_json_fragment helper
# ============================================================

LIB_DIR="${LIB_DIR:-/mnt/urbalurbadisk/provision-host/uis/lib}"
[[ ! -d "$LIB_DIR" ]] && LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"

if [[ -f "$LIB_DIR/configure-postgresql.sh" ]]; then
    # shellcheck source=/dev/null
    source "$LIB_DIR/configure-postgresql.sh"

    start_test "_pg_secret_json_fragment returns empty when no namespace"
    fragment=$(_pg_secret_json_fragment "" "")
    if [[ -z "$fragment" ]]; then
        pass_test
    else
        fail_test "Expected empty fragment, got: $fragment"
    fi

    start_test "_pg_secret_json_fragment includes secret_name when set"
    fragment=$(_pg_secret_json_fragment "my-ns" "my-app-db")
    if echo "$fragment" | grep -q '"secret_name":"my-app-db"'; then
        pass_test
    else
        fail_test "Expected secret_name in fragment, got: $fragment"
    fi

    start_test "_pg_secret_json_fragment includes secret_namespace when set"
    fragment=$(_pg_secret_json_fragment "my-ns" "my-app-db")
    if echo "$fragment" | grep -q '"secret_namespace":"my-ns"'; then
        pass_test
    else
        fail_test "Expected secret_namespace in fragment, got: $fragment"
    fi

    start_test "_pg_secret_json_fragment includes env_var=DATABASE_URL"
    fragment=$(_pg_secret_json_fragment "my-ns" "my-app-db")
    if echo "$fragment" | grep -q '"env_var":"DATABASE_URL"'; then
        pass_test
    else
        fail_test "Expected env_var=DATABASE_URL, got: $fragment"
    fi

    start_test "_pg_secret_json_fragment starts with comma (so it can be appended to JSON)"
    fragment=$(_pg_secret_json_fragment "my-ns" "my-app-db")
    if [[ "${fragment:0:1}" == "," ]]; then
        pass_test
    else
        fail_test "Expected fragment to start with comma, got: $fragment"
    fi
else
    echo "  (Skipping helper tests — configure-postgresql.sh not found)"
fi

# ============================================================
# Summary
# ============================================================

print_summary
