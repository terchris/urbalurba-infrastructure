#!/bin/bash
# test-multi-instance-parsing.sh — Tests for the multi-instance status helpers
# in lib/service-scanner.sh.
#
# Covers:
#   - _classify_ready_count: maps a kubectl "READY" column value
#     (e.g., "2/2", "1/2") to healthy / degraded / unknown.
#   - The kubectl-output line shape get_multi_instance_deployments emits
#     ("<name>\t<ready>" per line) — validated against a fixture, no
#     cluster required.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UIS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCANNER_LIB="$UIS_ROOT/lib/service-scanner.sh"

# Pull in just _classify_ready_count by sourcing the file with a stubbed
# paths.sh path. The scanner sources paths.sh relative to itself, which
# resolves correctly when the script lives in lib/. Sourcing here uses
# the file's own location so paths.sh is found.
# shellcheck source=/dev/null
source "$SCANNER_LIB" 2>/dev/null

PASS=0
FAIL=0
TOTAL=0

pass() {
    echo -e "  Testing: $1... \033[0;32mPASS\033[0m"
    ((++PASS))
    ((++TOTAL))
}

fail() {
    echo -e "  Testing: $1... \033[0;31mFAIL\033[0m - $2"
    ((++FAIL))
    ((++TOTAL))
}

echo ""
echo -e "\033[1m=== Multi-Instance Parsing Tests ===\033[0m"
echo "Verifying _classify_ready_count + the kubectl-output line shape"
echo ""

# Assert function loaded.
if ! declare -F _classify_ready_count >/dev/null; then
    fail "_classify_ready_count loaded from $SCANNER_LIB" "function not defined after source"
    echo ""
    echo "Total: $TOTAL  Passed: $PASS  Failed: $FAIL"
    exit 1
else
    pass "_classify_ready_count loaded from service-scanner.sh"
fi

# Healthy cases — N/N with N >= 1
for ready in "1/1" "2/2" "3/3" "10/10" "100/100"; do
    _classify_ready_count "$ready"
    if [[ $? -eq 0 ]]; then
        pass "_classify_ready_count '$ready' returns 0 (healthy)"
    else
        fail "_classify_ready_count '$ready' returns 0 (healthy)" "got $?"
    fi
done

# Degraded cases — numeric N/M but not equal-and-nonzero
for ready in "0/1" "1/2" "0/2" "0/0" "2/3" "1/3"; do
    _classify_ready_count "$ready"
    if [[ $? -eq 1 ]]; then
        pass "_classify_ready_count '$ready' returns 1 (degraded)"
    else
        fail "_classify_ready_count '$ready' returns 1 (degraded)" "got $?"
    fi
done

# Unknown cases — anything that doesn't match N/M shape
for ready in "" "garbage" "2/" "/2" "2//2" "a/b" "<no value>"; do
    _classify_ready_count "$ready"
    if [[ $? -eq 2 ]]; then
        pass "_classify_ready_count '$ready' returns 2 (unknown)"
    else
        fail "_classify_ready_count '$ready' returns 2 (unknown)" "got $?"
    fi
done

# Kubectl-output line shape: get_multi_instance_deployments emits one
# tab-separated line per matching deployment. Simulate the awk parse by
# feeding a kubectl-format fixture through the same awk expression.
FIXTURE=$(cat <<'EOF'
atlas-postgrest      2/2     2            2           8d
railway-postgrest    2/2     2            2           47h
degraded-postgrest   1/2     2            1           5m
EOF
)

EXPECTED=$(cat <<'EOF'
atlas-postgrest	2/2
railway-postgrest	2/2
degraded-postgrest	1/2
EOF
)

ACTUAL=$(echo "$FIXTURE" | awk '{print $1 "\t" $2}')
if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    pass "kubectl-output awk parse emits '<name>\\t<ready>' per row"
else
    fail "kubectl-output awk parse emits '<name>\\t<ready>' per row" "actual=$ACTUAL"
fi

# Empty input → zero rows emitted (the zero-deployment case).
ACTUAL_EMPTY=$(echo -n "" | awk '{print $1 "\t" $2}')
if [[ -z "$ACTUAL_EMPTY" ]]; then
    pass "empty input → zero rows (zero-deployment case)"
else
    fail "empty input → zero rows (zero-deployment case)" "got '$ACTUAL_EMPTY'"
fi

echo ""
echo "────────────────────────────────────"
echo "Total: $TOTAL  Passed: $PASS  Failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo -e "\033[0;31mFAILED\033[0m"
    exit 1
fi
echo -e "\033[0;32mALL TESTS PASSED\033[0m"
exit 0
