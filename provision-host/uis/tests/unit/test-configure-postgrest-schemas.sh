#!/bin/bash
# test-configure-postgrest-schemas.sh — Unit tests for the --schemas flag
#
# Covers:
#   - _pgrst_normalize_schemas() — R4 string-level checks (R4 steps 1–3:
#     trim/empty/regex/dedup). The DB existence check (R4 step 4) is
#     integration-level and lives in deploy/test-configure-postgrest-schemas-integration.sh.
#   - CLI parsing: --schemas accepted on configure path; --schema rejected
#     as an unknown option (no aliasing — R5 in the investigation).
#
# No cluster needed. Sources the helper directly and shells out to uis-cli.sh
# for the CLI-parsing assertions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_LIB="/mnt/urbalurbadisk/provision-host/uis/lib"
    UIS_CLI="/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh"
else
    UIS_LIB="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
    UIS_CLI="$(cd "$SCRIPT_DIR/../../manage" && pwd)/uis-cli.sh"
fi

# Source the handler to get _pgrst_normalize_schemas. logging.sh is needed
# for log_warn (used on duplicate detection).
source "$UIS_LIB/logging.sh"
source "$UIS_LIB/configure-postgrest.sh"

# ============================================================================
# _pgrst_normalize_schemas — happy paths
# ============================================================================

print_test_section "Normalizer: happy paths"

start_test "single schema returns unchanged"
out=$(_pgrst_normalize_schemas "api_v1" 2>/dev/null)
[[ "$out" == "api_v1" ]] && pass_test || fail_test "got: $out"

start_test "three schemas returns comma-separated"
out=$(_pgrst_normalize_schemas "api_v1,marts,raw" 2>/dev/null)
[[ "$out" == "api_v1,marts,raw" ]] && pass_test || fail_test "got: $out"

start_test "leading/trailing whitespace per component is trimmed"
out=$(_pgrst_normalize_schemas " api_v1 , marts , raw " 2>/dev/null)
[[ "$out" == "api_v1,marts,raw" ]] && pass_test || fail_test "got: $out"

start_test "underscore + digit identifiers accepted"
out=$(_pgrst_normalize_schemas "api_v1,_internal,table_2" 2>/dev/null)
[[ "$out" == "api_v1,_internal,table_2" ]] && pass_test || fail_test "got: $out"

# ============================================================================
# _pgrst_normalize_schemas — rejection paths (R4 string-level)
# ============================================================================

print_test_section "Normalizer: rejection paths"

start_test "empty string rejected"
_pgrst_normalize_schemas "" 2>/dev/null && fail_test "should have rejected empty input" || pass_test

start_test "consecutive commas (empty component) rejected"
_pgrst_normalize_schemas "api_v1,,marts" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "trailing comma rejected"
_pgrst_normalize_schemas "api_v1,marts," 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "leading comma rejected"
_pgrst_normalize_schemas ",api_v1,marts" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "whitespace-only component rejected"
_pgrst_normalize_schemas "api_v1, ,marts" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "hyphen in identifier rejected (not a valid Postgres unquoted identifier)"
_pgrst_normalize_schemas "api_v1,bad-name" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "leading digit rejected"
_pgrst_normalize_schemas "1bad" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "SQL-injection attempt rejected (semicolon + statement)"
_pgrst_normalize_schemas "api_v1; DROP TABLE users;--" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "single quote rejected"
_pgrst_normalize_schemas "api_v1,bad'name" 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "double quote rejected"
_pgrst_normalize_schemas 'api_v1,bad"name' 2>/dev/null && fail_test "should have rejected" || pass_test

start_test "backslash rejected"
_pgrst_normalize_schemas 'api_v1,bad\name' 2>/dev/null && fail_test "should have rejected" || pass_test

# ============================================================================
# _pgrst_normalize_schemas — duplicate handling
# ============================================================================

print_test_section "Normalizer: duplicate handling"

start_test "exact duplicate de-duped, first occurrence preserved"
out=$(_pgrst_normalize_schemas "api_v1,api_v1,marts" 2>/dev/null)
[[ "$out" == "api_v1,marts" ]] && pass_test || fail_test "got: $out"

start_test "duplicate prints warning to stderr"
err=$(_pgrst_normalize_schemas "api_v1,api_v1,marts" 2>&1 >/dev/null)
echo "$err" | grep -qi "duplicate" && pass_test || fail_test "got stderr: $err"

start_test "duplicate at end de-duped"
out=$(_pgrst_normalize_schemas "api_v1,marts,api_v1" 2>/dev/null)
[[ "$out" == "api_v1,marts" ]] && pass_test || fail_test "got: $out"

start_test "all-duplicate input collapses to single value"
out=$(_pgrst_normalize_schemas "api_v1,api_v1,api_v1" 2>/dev/null)
[[ "$out" == "api_v1" ]] && pass_test || fail_test "got: $out"

# ============================================================================
# CLI parsing: --schema is no longer accepted (R5)
#
# These shell out to uis-cli.sh, which only runs cleanly inside the
# uis-provision-host container (its lib dependencies expect container paths).
# Skip when running on the host so the normalizer unit tests above still
# give a useful local signal; CI runs inside the container.
# ============================================================================

print_test_section "CLI parsing: --schema is gone, --schemas is the only flag"

if [[ ! -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    skip_test "Skipping CLI parsing tests: not running inside uis-provision-host container"
    skip_test "Skipping CLI parsing tests: not running inside uis-provision-host container"
    skip_test "Skipping CLI parsing tests: not running inside uis-provision-host container"
else
    start_test "configure: --schema returns 'Unknown option' error"
    output=$("$UIS_CLI" configure postgrest --app atlas --database atlas_db --schema api_v1 2>&1 || true)
    echo "$output" | grep -qi "unknown option" && pass_test || fail_test "expected 'Unknown option' in: $output"

    start_test "deploy: --schema returns 'Unknown option' error"
    output=$("$UIS_CLI" deploy postgrest --app atlas --schema api_v1 2>&1 || true)
    echo "$output" | grep -qi "unknown option" && pass_test || fail_test "expected 'Unknown option' in: $output"

    start_test "deploy: --schemas returns 'Unknown option' error (deploy doesn't take schema flags)"
    output=$("$UIS_CLI" deploy postgrest --app atlas --schemas api_v1,marts 2>&1 || true)
    echo "$output" | grep -qi "unknown option" && pass_test || fail_test "expected 'Unknown option' in: $output"
fi

# ============================================================================
# Summary
# ============================================================================

print_summary
