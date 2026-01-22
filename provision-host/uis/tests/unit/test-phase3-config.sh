#!/bin/bash
# test-phase3-config.sh - Phase 3 config system tests
#
# Tests for first-run initialization, service deployment, and config templates.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine paths (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
    TEMPLATES_DIR="/mnt/urbalurbadisk/provision-host/uis/templates"
else
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
    TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../../templates" && pwd)"
fi

print_test_section "Phase 3: Config System Tests"

# ============================================================
# Test first-run.sh
# ============================================================

start_test "first-run.sh exists"
if [[ -f "$LIB_DIR/first-run.sh" ]]; then
    pass_test
else
    fail_test "File not found: $LIB_DIR/first-run.sh"
fi

start_test "first-run.sh loads without error"
if bash -n "$LIB_DIR/first-run.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Syntax error in first-run.sh"
fi

# Source first-run.sh for function tests (need to set paths first)
EXTEND_DIR="/tmp/test-uis-extend-$$"
SECRETS_DIR="/tmp/test-uis-secrets-$$"
export EXTEND_DIR SECRETS_DIR TEMPLATES_DIR
source "$LIB_DIR/first-run.sh" 2>/dev/null

FIRST_RUN_FUNCTIONS=(
    check_first_run
    copy_defaults_if_missing
    validate_config_structure
    initialize_uis_config
    load_cluster_config
    get_default_secret
    is_using_default_secrets
)

for fn in "${FIRST_RUN_FUNCTIONS[@]}"; do
    start_test "first-run.sh defines $fn"
    if type "$fn" &>/dev/null; then
        pass_test
    else
        fail_test "Function not defined: $fn"
    fi
done

# ============================================================
# Test service-deployment.sh
# ============================================================

start_test "service-deployment.sh exists"
if [[ -f "$LIB_DIR/service-deployment.sh" ]]; then
    pass_test
else
    fail_test "File not found: $LIB_DIR/service-deployment.sh"
fi

start_test "service-deployment.sh loads without error"
if bash -n "$LIB_DIR/service-deployment.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Syntax error in service-deployment.sh"
fi

# Source service-deployment.sh for function tests
source "$LIB_DIR/service-deployment.sh" 2>/dev/null

DEPLOY_FUNCTIONS=(
    read_enabled_services
    deploy_enabled_services
    deploy_single_service
    remove_single_service
    check_dependencies
    get_services_by_priority
    show_deployment_status
)

for fn in "${DEPLOY_FUNCTIONS[@]}"; do
    start_test "service-deployment.sh defines $fn"
    if type "$fn" &>/dev/null; then
        pass_test
    else
        fail_test "Function not defined: $fn"
    fi
done

# ============================================================
# Test template files exist
# ============================================================

start_test "templates/uis.extend/ directory exists"
if [[ -d "$TEMPLATES_DIR/uis.extend" ]]; then
    pass_test
else
    fail_test "Directory not found: $TEMPLATES_DIR/uis.extend"
fi

start_test "templates/uis.secrets/ directory exists"
if [[ -d "$TEMPLATES_DIR/uis.secrets" ]]; then
    pass_test
else
    fail_test "Directory not found: $TEMPLATES_DIR/uis.secrets"
fi

TEMPLATE_FILES=(
    "uis.extend/enabled-services.conf.default"
    "uis.extend/enabled-tools.conf.default"
    "uis.extend/cluster-config.sh.default"
    "uis.extend/README.md"
    "uis.secrets/README.md"
    "uis.secrets/.gitignore"
    "default-secrets.env"
)

for template in "${TEMPLATE_FILES[@]}"; do
    start_test "template $template exists"
    if [[ -f "$TEMPLATES_DIR/$template" ]]; then
        pass_test
    else
        fail_test "Template not found: $TEMPLATES_DIR/$template"
    fi
done

# ============================================================
# Test enabled-services.conf format
# ============================================================

start_test "enabled-services.conf.default has nginx enabled"
if grep -q "^nginx" "$TEMPLATES_DIR/uis.extend/enabled-services.conf.default" 2>/dev/null; then
    pass_test
else
    fail_test "nginx not found as enabled service in default config"
fi

start_test "enabled-services.conf.default has comments"
if grep -q "^#" "$TEMPLATES_DIR/uis.extend/enabled-services.conf.default" 2>/dev/null; then
    pass_test
else
    fail_test "No comments found in enabled-services.conf.default"
fi

# ============================================================
# Test cluster-config.sh format
# ============================================================

start_test "cluster-config.sh.default defines CLUSTER_TYPE"
if grep -q "CLUSTER_TYPE=" "$TEMPLATES_DIR/uis.extend/cluster-config.sh.default" 2>/dev/null; then
    pass_test
else
    fail_test "CLUSTER_TYPE not defined in cluster-config.sh.default"
fi

start_test "cluster-config.sh.default defines BASE_DOMAIN"
if grep -q "BASE_DOMAIN=" "$TEMPLATES_DIR/uis.extend/cluster-config.sh.default" 2>/dev/null; then
    pass_test
else
    fail_test "BASE_DOMAIN not defined in cluster-config.sh.default"
fi

# ============================================================
# Test default-secrets.env format
# ============================================================

start_test "default-secrets.env defines DEFAULT_ADMIN_PASSWORD"
if grep -q "DEFAULT_ADMIN_PASSWORD=" "$TEMPLATES_DIR/default-secrets.env" 2>/dev/null; then
    pass_test
else
    fail_test "DEFAULT_ADMIN_PASSWORD not defined in default-secrets.env"
fi

start_test "default-secrets.env defines DEFAULT_DATABASE_PASSWORD"
if grep -q "DEFAULT_DATABASE_PASSWORD=" "$TEMPLATES_DIR/default-secrets.env" 2>/dev/null; then
    pass_test
else
    fail_test "DEFAULT_DATABASE_PASSWORD not defined in default-secrets.env"
fi

# ============================================================
# Test check_first_run function
# ============================================================

# Create temp test directories
mkdir -p "$EXTEND_DIR" "$SECRETS_DIR"

start_test "check_first_run returns 1 when config missing"
if ! check_first_run; then
    pass_test
else
    fail_test "check_first_run should return 1 when enabled-services.conf missing"
fi

# Create the config file
echo "nginx" > "$EXTEND_DIR/enabled-services.conf"

start_test "check_first_run returns 0 when config exists"
if check_first_run; then
    pass_test
else
    fail_test "check_first_run should return 0 when enabled-services.conf exists"
fi

# Cleanup temp directories
rm -rf "$EXTEND_DIR" "$SECRETS_DIR"

print_summary
