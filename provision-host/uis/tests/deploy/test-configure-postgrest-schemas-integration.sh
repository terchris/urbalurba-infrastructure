#!/bin/bash
# test-configure-postgrest-schemas-integration.sh — Integration tests for the
# --schemas flag and State Matrix dispatch in configure-postgrest.sh.
#
# REQUIRES: Running K8s cluster with PostgreSQL deployed.
# Run: uis deploy postgresql (before running these tests).
#
# These tests create and remove resources in the cluster:
# - A test database (created via psql; not via uis configure postgresql,
#   to keep this file self-contained and avoid coupling to that handler).
# - A pair of per-app roles (<app>_web_anon, <app>_authenticator).
# - Test schemas (api_v1, marts, raw) populated in the test database.
# - A per-app secret in the postgrest namespace.
#
# All resources use a TEST_TIMESTAMP-suffixed name to avoid collision with
# real deployments. Teardown runs at end via trap.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_CLI="/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh"
else
    UIS_CLI="$(cd "$SCRIPT_DIR/../../manage" && pwd)/uis-cli.sh"
fi

TEST_TIMESTAMP=$(date +%s)
TEST_APP="pgrst-test-${TEST_TIMESTAMP}"
TEST_DB="pgrst_test_${TEST_TIMESTAMP}"
TEST_WEB_ANON="${TEST_APP//-/_}_web_anon"
TEST_AUTH="${TEST_APP//-/_}_authenticator"
TEST_SECRET="${TEST_APP}-postgrest"
TEST_NS="postgrest"

# --- helpers ---------------------------------------------------------------

_psql_admin() {
    # Run psql as the admin against the cluster's postgres pod. Returns stdout
    # of the query; merges stderr so failures are visible in test output.
    local sql="$1"
    local db="${2:-postgres}"
    local pod
    pod=$(kubectl get pods -n default -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')
    local pw
    pw=$(kubectl get secret urbalurba-secrets -n default -o jsonpath='{.data.PGPASSWORD}' | base64 -d)
    kubectl exec -n default "$pod" -- env PGPASSWORD="$pw" psql -U postgres -d "$db" -tAc "$sql" 2>&1
}

_assert_has_usage() {
    local schema="$1"
    local result
    result=$(_psql_admin "SELECT has_schema_privilege('$TEST_WEB_ANON', '$schema', 'USAGE')" "$TEST_DB")
    [[ "$result" == "t" ]]
}

_count_default_acl_for_role() {
    # Count pg_default_acl rows in $TEST_DB whose acl mentions the test
    # web_anon role and target the named schema.
    local schema="$1"
    _psql_admin "SELECT count(*) FROM pg_default_acl WHERE defaclnamespace=(SELECT oid FROM pg_namespace WHERE nspname='$schema') AND defaclacl::text LIKE '%${TEST_WEB_ANON}%'" "$TEST_DB"
}

_secret_key() {
    local key="$1"
    kubectl get secret "$TEST_SECRET" -n "$TEST_NS" -o jsonpath="{.data.${key}}" 2>/dev/null | base64 -d 2>/dev/null
}

_teardown() {
    echo "" >&2
    echo "─── teardown ───" >&2
    "$UIS_CLI" configure postgrest --app "$TEST_APP" --purge --json >/dev/null 2>&1 || true
    _psql_admin "DROP DATABASE IF EXISTS $TEST_DB" >/dev/null 2>&1 || true
    _psql_admin "DROP ROLE IF EXISTS $TEST_AUTH" >/dev/null 2>&1 || true
    _psql_admin "DROP ROLE IF EXISTS $TEST_WEB_ANON" >/dev/null 2>&1 || true
    kubectl delete secret "$TEST_SECRET" -n "$TEST_NS" >/dev/null 2>&1 || true
}
trap _teardown EXIT

# --- pre-flight -----------------------------------------------------------

print_test_section "Integration: pre-flight"

start_test "kubectl is available"
if command -v kubectl &>/dev/null; then pass_test; else fail_test "kubectl not found"; print_summary; exit 1; fi

start_test "PostgreSQL is deployed"
if kubectl get pods -n default -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | grep -q Running; then
    pass_test
else
    fail_test "PostgreSQL is not running. Run: uis deploy postgresql"
    print_summary
    exit 1
fi

start_test "create test database + schemas"
_psql_admin "CREATE DATABASE $TEST_DB" >/dev/null
_psql_admin "CREATE SCHEMA api_v1; CREATE SCHEMA marts; CREATE SCHEMA raw; CREATE TABLE api_v1.t1 (id int); CREATE TABLE marts.t2 (id int); CREATE TABLE raw.t3 (id int);" "$TEST_DB" >/dev/null
pass_test

# --- 6.3 first-time configure --------------------------------------------

print_test_section "6.3: first-time configure with --schemas api_v1,marts,raw"

start_test "configure exits ok"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,marts,raw --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "ok" ]] && pass_test || fail_test "got: $output"

start_test "JSON includes path=first-time"
path=$(echo "$output" | jq -r '.path' 2>/dev/null)
[[ "$path" == "first-time" ]] && pass_test || fail_test "got path=$path"

start_test "JSON includes schemas=api_v1,marts,raw"
schemas_out=$(echo "$output" | jq -r '.schemas' 2>/dev/null)
[[ "$schemas_out" == "api_v1,marts,raw" ]] && pass_test || fail_test "got: $schemas_out"

start_test "USAGE granted on api_v1"
_assert_has_usage api_v1 && pass_test || fail_test "no USAGE"

start_test "USAGE granted on marts"
_assert_has_usage marts && pass_test || fail_test "no USAGE"

start_test "USAGE granted on raw"
_assert_has_usage raw && pass_test || fail_test "no USAGE"

start_test "secret has PGRST_DB_URI key"
[[ -n "$(_secret_key PGRST_DB_URI)" ]] && pass_test || fail_test "URI missing"

start_test "secret PGRST_DB_SCHEMAS == api_v1,marts,raw"
[[ "$(_secret_key PGRST_DB_SCHEMAS)" == "api_v1,marts,raw" ]] && pass_test || fail_test "got: $(_secret_key PGRST_DB_SCHEMAS)"

# --- 6.4 idempotent re-run ------------------------------------------------

print_test_section "6.4: re-run with same list — no-op"

start_test "re-run returns already_configured"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,marts,raw --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "already_configured" ]] && pass_test || fail_test "got: $output"

# --- 6.5 reconfigure: drop a schema --------------------------------------

print_test_section "6.5: reconfigure --schemas api_v1,marts (drop raw)"

start_test "configure exits ok"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,marts --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "ok" ]] && pass_test || fail_test "got: $output"

start_test "path=reconfigure-preserve-uri"
path=$(echo "$output" | jq -r '.path' 2>/dev/null)
[[ "$path" == "reconfigure-preserve-uri" ]] && pass_test || fail_test "got path=$path"

start_test "USAGE on raw revoked"
result=$(_psql_admin "SELECT has_schema_privilege('$TEST_WEB_ANON', 'raw', 'USAGE')" "$TEST_DB")
[[ "$result" == "f" ]] && pass_test || fail_test "USAGE still granted (got: $result)"

start_test "pg_default_acl cleared for raw"
count=$(_count_default_acl_for_role raw)
[[ "$count" == "0" ]] && pass_test || fail_test "expected 0, got: $count"

start_test "USAGE on api_v1 + marts still granted"
_assert_has_usage api_v1 && _assert_has_usage marts && pass_test || fail_test "missing grants"

start_test "secret PGRST_DB_SCHEMAS updated to api_v1,marts"
[[ "$(_secret_key PGRST_DB_SCHEMAS)" == "api_v1,marts" ]] && pass_test || fail_test "got: $(_secret_key PGRST_DB_SCHEMAS)"

# --- 6.6 order-only change -----------------------------------------------

print_test_section "6.6: order-only change marts,api_v1"

start_test "configure exits ok"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas marts,api_v1 --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "ok" ]] && pass_test || fail_test "got: $output"

start_test "secret value reflects new order"
[[ "$(_secret_key PGRST_DB_SCHEMAS)" == "marts,api_v1" ]] && pass_test || fail_test "got: $(_secret_key PGRST_DB_SCHEMAS)"

start_test "grants unchanged (set-equal end state)"
_assert_has_usage api_v1 && _assert_has_usage marts && pass_test || fail_test "missing grants"

# --- 6.7 missing schema rejected by pre-validation ------------------------

print_test_section "6.7: missing schema rejected before any state change"

start_test "configure with bogus schema returns error"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,bogus_xyz --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "error" ]] && pass_test || fail_test "got: $output"

start_test "existing grants unchanged after rejection"
_assert_has_usage marts && _assert_has_usage api_v1 && pass_test || fail_test "grants disturbed"

start_test "secret PGRST_DB_SCHEMAS unchanged after rejection"
[[ "$(_secret_key PGRST_DB_SCHEMAS)" == "marts,api_v1" ]] && pass_test || fail_test "secret modified"

# --- 6.8 authenticator membership survives DROP OWNED BY ------------------

print_test_section "6.8: <app>_authenticator → <app>_web_anon membership"

start_test "membership exists after the previous reconfigure"
result=$(_psql_admin "SELECT EXISTS (SELECT 1 FROM pg_auth_members WHERE roleid=(SELECT oid FROM pg_authid WHERE rolname='$TEST_WEB_ANON') AND member=(SELECT oid FROM pg_authid WHERE rolname='$TEST_AUTH'))")
[[ "$result" == "t" ]] && pass_test || fail_test "membership lost (got: $result)"

# --- 6.9 rotate fails when PGRST_DB_SCHEMAS missing -----------------------

print_test_section "6.9: rotate fails loudly on PLAN-002-era secret"

start_test "remove PGRST_DB_SCHEMAS key from secret"
kubectl patch secret "$TEST_SECRET" -n "$TEST_NS" --type=json -p='[{"op":"remove","path":"/data/PGRST_DB_SCHEMAS"}]' >/dev/null
[[ -z "$(_secret_key PGRST_DB_SCHEMAS)" ]] && pass_test || fail_test "key still present"

start_test "rotate fails with the prescribed error"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --rotate --json 2>&1)
echo "$output" | grep -q "PGRST_DB_SCHEMAS not present" && pass_test || fail_test "got: $output"

# --- 6.11 PLAN-002 upgrade path -------------------------------------------

print_test_section "6.11: PLAN-002 upgrade — secret has only PGRST_DB_URI"

# (Continuing from 6.9: the secret now has only PGRST_DB_URI. Capture it
# so we can verify the URI is preserved.)
start_test "capture pre-upgrade PGRST_DB_URI"
PRE_UPGRADE_URI=$(_secret_key PGRST_DB_URI)
[[ -n "$PRE_UPGRADE_URI" ]] && pass_test || fail_test "URI missing pre-upgrade"

start_test "configure with --schemas adds the missing key"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,marts --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "ok" ]] && pass_test || fail_test "got: $output"

start_test "path=reconfigure-preserve-uri"
path=$(echo "$output" | jq -r '.path' 2>/dev/null)
[[ "$path" == "reconfigure-preserve-uri" ]] && pass_test || fail_test "got path=$path"

start_test "PGRST_DB_URI preserved verbatim"
[[ "$(_secret_key PGRST_DB_URI)" == "$PRE_UPGRADE_URI" ]] && pass_test || fail_test "URI changed"

start_test "PGRST_DB_SCHEMAS now populated"
[[ "$(_secret_key PGRST_DB_SCHEMAS)" == "api_v1,marts" ]] && pass_test || fail_test "got: $(_secret_key PGRST_DB_SCHEMAS)"

# --- 6.10 recovery: secret deleted manually -------------------------------

print_test_section "6.10: recovery — delete secret, reconfigure"

start_test "capture pre-deletion URI for comparison"
PRE_DELETE_URI=$(_secret_key PGRST_DB_URI)
[[ -n "$PRE_DELETE_URI" ]] && pass_test || fail_test "URI missing"

start_test "delete secret"
kubectl delete secret "$TEST_SECRET" -n "$TEST_NS" >/dev/null
[[ -z "$(_secret_key PGRST_DB_URI)" ]] && pass_test || fail_test "secret still exists"

start_test "configure rebuilds secret"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,marts --json 2>&1)
status=$(echo "$output" | jq -r '.status' 2>/dev/null)
[[ "$status" == "ok" ]] && pass_test || fail_test "got: $output"

start_test "path=reconfigure-fresh-password"
path=$(echo "$output" | jq -r '.path' 2>/dev/null)
[[ "$path" == "reconfigure-fresh-password" ]] && pass_test || fail_test "got path=$path"

start_test "new URI differs from pre-deletion (password rotated)"
[[ "$(_secret_key PGRST_DB_URI)" != "$PRE_DELETE_URI" ]] && pass_test || fail_test "URI unchanged"

start_test "secret has both keys"
[[ -n "$(_secret_key PGRST_DB_URI)" && -n "$(_secret_key PGRST_DB_SCHEMAS)" ]] && pass_test || fail_test "key missing"

# --- 6.12 partial role state ----------------------------------------------

print_test_section "6.12: partial role state — error and refuse to act"

start_test "drop authenticator role"
kubectl delete secret "$TEST_SECRET" -n "$TEST_NS" >/dev/null 2>&1 || true
_psql_admin "DROP ROLE IF EXISTS $TEST_AUTH" >/dev/null
result=$(_psql_admin "SELECT count(*) FROM pg_roles WHERE rolname='$TEST_AUTH'")
[[ "$result" == "0" ]] && pass_test || fail_test "role still exists"

start_test "configure errors with 'Inconsistent role state'"
output=$("$UIS_CLI" configure postgrest --app "$TEST_APP" --database "$TEST_DB" --schemas api_v1,marts --json 2>&1)
echo "$output" | grep -q "Inconsistent role state" && pass_test || fail_test "got: $output"

# --- summary --------------------------------------------------------------

print_summary
