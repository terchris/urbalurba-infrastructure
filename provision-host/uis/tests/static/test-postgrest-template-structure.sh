#!/bin/bash
# test-postgrest-template-structure.sh — Static checks on the postgrest
# Ansible Jinja2 templates.
#
# These guard against regressions where someone reverts the deploy template
# from `valueFrom.secretKeyRef` back to an inline `value: "{{ _schema }}"`
# (the PLAN-002 shape). That regression would silently break multi-schema
# setups: the playbook would still render, but the running pod would only
# expose whatever the operator passed via --schema/--schemas on deploy
# (now: nothing, since deploy doesn't take that flag).
#
# Cheap, deterministic, no cluster needed. Runs as part of static tests in
# CI's "Test UIS Scripts" workflow.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Locate the Ansible playbook templates dir (works in container + on host).
if [[ -d "/mnt/urbalurbadisk/ansible/playbooks/templates" ]]; then
    TEMPLATES_DIR="/mnt/urbalurbadisk/ansible/playbooks/templates"
else
    TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../../../../ansible/playbooks/templates" && pwd)"
fi

CONFIG_TEMPLATE="$TEMPLATES_DIR/088-postgrest-config.yml.j2"
SETUP_PLAYBOOK="$(dirname "$TEMPLATES_DIR")/088-setup-postgrest.yml"

print_test_section "PostgREST deploy-template structure (static)"

# ============================================================================
# Template file existence
# ============================================================================

start_test "088-postgrest-config.yml.j2 exists"
[[ -f "$CONFIG_TEMPLATE" ]] && pass_test || fail_test "$CONFIG_TEMPLATE missing"

start_test "088-setup-postgrest.yml exists"
[[ -f "$SETUP_PLAYBOOK" ]] && pass_test || fail_test "$SETUP_PLAYBOOK missing"

# ============================================================================
# PGRST_DB_URI must use valueFrom.secretKeyRef (existing PLAN-002 shape)
# ============================================================================

start_test "PGRST_DB_URI uses valueFrom.secretKeyRef"
# Look for the env entry's secretKeyRef block immediately after PGRST_DB_URI.
# `awk` extracts the next 4 lines after the `name: PGRST_DB_URI` marker so
# we can grep that window for `secretKeyRef`.
window=$(awk '/name: PGRST_DB_URI/{flag=1; c=0} flag{print; c++; if (c==5) exit}' "$CONFIG_TEMPLATE")
echo "$window" | grep -q 'secretKeyRef' && pass_test || fail_test "got: $window"

start_test "PGRST_DB_URI references key 'PGRST_DB_URI'"
echo "$window" | grep -q 'key: PGRST_DB_URI' && pass_test || fail_test "got: $window"

# ============================================================================
# PGRST_DB_SCHEMAS must use valueFrom.secretKeyRef — this is the new shape.
# Regression guard: if someone reverts to `value: "{{ _schema }}"`, this
# fails fast before the change reaches the cluster.
# ============================================================================

start_test "PGRST_DB_SCHEMAS uses valueFrom.secretKeyRef (not inline value)"
window=$(awk '/name: PGRST_DB_SCHEMAS/{flag=1; c=0} flag{print; c++; if (c==5) exit}' "$CONFIG_TEMPLATE")
echo "$window" | grep -q 'secretKeyRef' && pass_test || fail_test "got: $window"

start_test "PGRST_DB_SCHEMAS does NOT have an inline 'value:' field"
echo "$window" | grep -qE '^[[:space:]]+value:' && \
    fail_test "found inline 'value:' field — should be valueFrom.secretKeyRef. Window: $window" || \
    pass_test

start_test "PGRST_DB_SCHEMAS references key 'PGRST_DB_SCHEMAS'"
echo "$window" | grep -q 'key: PGRST_DB_SCHEMAS' && pass_test || fail_test "got: $window"

start_test "PGRST_DB_SCHEMAS references the per-app secret"
echo "$window" | grep -q 'name: "{{ _app_name }}-postgrest"' && pass_test || fail_test "got: $window"

# ============================================================================
# The template must NOT reference {{ _schema }} (PLAN-002-era extra-var).
# ============================================================================

start_test "Template does not reference {{ _schema }} extra-var anywhere"
if grep -q '{{ _schema }}' "$CONFIG_TEMPLATE"; then
    fail_test "Found {{ _schema }} in $CONFIG_TEMPLATE — should be sourced from secret"
else
    pass_test
fi

# ============================================================================
# The setup playbook must NOT require _schema as an extra-var.
# ============================================================================

start_test "088-setup-postgrest.yml does not require _schema in its assertion"
# The assertion lists required extra-vars; _schema must not be in that list.
# Tolerate _schema appearing in a comment (e.g. historical context).
assert_block=$(awk '/Validate required extra-vars/,/fail_msg:/' "$SETUP_PLAYBOOK")
if echo "$assert_block" | grep -E '^[[:space:]]+- _schema' >/dev/null; then
    fail_test "Found _schema in extra-vars assertion. Block: $assert_block"
else
    pass_test
fi

# ============================================================================
# Summary
# ============================================================================

print_summary
