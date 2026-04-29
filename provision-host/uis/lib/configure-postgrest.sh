#!/bin/bash
# configure-postgrest.sh — PostgREST handler for uis configure
#
# PostgREST is a multi-instance service: each consuming application gets its own
# Deployment in the shared postgrest namespace, configured separately. This handler
# creates per-app Postgres roles in the platform's PostgreSQL instance, generates a
# password, and writes a secret in the postgrest namespace that the per-app
# PostgREST Deployment will mount.
#
# See:
#   - INVESTIGATE-postgrest.md (decisions, addendum on ALTER DEFAULT PRIVILEGES)
#   - PLAN-002-postgrest-deployment.md Phase 2

# PostgreSQL connection details (where we create the roles)
PG_ADMIN_USER="postgres"
PG_K8S_SVC="postgresql"
PG_NAMESPACE="default"
PG_INTERNAL_PORT=5432
PG_CLUSTER_HOST="postgresql.default.svc.cluster.local"

# PostgREST namespace (where the per-app Deployment + Secret live)
PGRST_NAMESPACE="postgrest"

# Get the postgresql admin password from urbalurba-secrets
_pgrst_get_admin_password() {
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    kubectl get secret urbalurba-secrets \
        -n "$PG_NAMESPACE" \
        --kubeconfig="$kubeconf" \
        -o jsonpath='{.data.PGPASSWORD}' 2>/dev/null | base64 -d
}

# Find the postgresql pod name
_pgrst_get_pod() {
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    kubectl get pods -n "$PG_NAMESPACE" \
        --kubeconfig="$kubeconf" \
        -l app.kubernetes.io/name=postgresql \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Run a SQL command as the postgres admin user
_pgrst_exec() {
    local sql="$1"
    local admin_pass="$2"
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    local pod
    pod=$(_pgrst_get_pod)

    if [[ -z "$pod" ]]; then
        return 1
    fi

    kubectl exec "$pod" \
        -n "$PG_NAMESPACE" \
        --kubeconfig="$kubeconf" \
        -- env PGPASSWORD="$admin_pass" psql -U "$PG_ADMIN_USER" -t -A -c "$sql" 2>/dev/null
}

# Check if a role exists
_pgrst_role_exists() {
    local role_name="$1"
    local admin_pass="$2"
    local result
    result=$(_pgrst_exec "SELECT 1 FROM pg_roles WHERE rolname='$role_name'" "$admin_pass")
    [[ "$result" == "1" ]]
}

# Check if a secret exists in the postgrest namespace
_pgrst_secret_exists() {
    local secret_name="$1"
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    kubectl get secret "$secret_name" -n "$PGRST_NAMESPACE" \
        --kubeconfig="$kubeconf" >/dev/null 2>&1
}

# Check if a per-app Deployment exists (used by --purge to refuse if k8s objects still present)
_pgrst_deployment_exists() {
    local deployment_name="$1"
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    kubectl get deployment "$deployment_name" -n "$PGRST_NAMESPACE" \
        --kubeconfig="$kubeconf" >/dev/null 2>&1
}

# Ensure a Kubernetes namespace exists (idempotent)
_pgrst_ensure_namespace() {
    local ns="$1"
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    kubectl create namespace "$ns" \
        --kubeconfig="$kubeconf" \
        --dry-run=client -o yaml 2>/dev/null \
        | kubectl apply --kubeconfig="$kubeconf" -f - >/dev/null 2>&1
}

# Create or update the per-app PGRST_DB_URI secret (idempotent)
_pgrst_create_secret() {
    local secret_name="$1"
    local db_uri="$2"
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"

    kubectl create secret generic "$secret_name" \
        --namespace="$PGRST_NAMESPACE" \
        --from-literal=PGRST_DB_URI="$db_uri" \
        --kubeconfig="$kubeconf" \
        --dry-run=client -o yaml 2>/dev/null \
        | kubectl apply --kubeconfig="$kubeconf" -f - >/dev/null 2>&1
}

# Delete the per-app secret
_pgrst_delete_secret() {
    local secret_name="$1"
    local kubeconf="${KUBECONF:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"
    kubectl delete secret "$secret_name" -n "$PGRST_NAMESPACE" \
        --kubeconfig="$kubeconf" >/dev/null 2>&1
}

# Main handler — called by configure.sh.
#
# Argument layout matches the run_configure dispatch in configure.sh:
#   $1=service_id $2=app_name $3=database_name $4=init_file $5=json_output
#   $6=namespace $7=secret_name_prefix $8=schema $9=url_prefix $10=rotate $11=purge
#
# Multi-instance handler convention: namespace/secret_name_prefix come from the
# generic --namespace / --secret-name-prefix flags but PostgREST rejects those
# (Decision #6) — namespace and secret name are platform-decided. We accept the
# args to keep dispatch consistent, then error if either is non-empty.
configure_service() {
    local service_id="$1"
    local app_name="$2"
    local database_name="$3"
    local init_file="$4"  # unused by postgrest
    local json_output="$5"
    local namespace="${6:-}"
    local secret_name_prefix="${7:-}"
    local schema="${8:-}"
    local url_prefix="${9:-}"
    local rotate="${10:-false}"
    local purge="${11:-false}"

    # Reject flags that don't apply to postgrest (Decision #6)
    if [[ -n "$namespace" || -n "$secret_name_prefix" ]]; then
        local msg="--namespace and --secret-name-prefix are not supported for postgrest. PostgREST manages its own namespace ($PGRST_NAMESPACE) and secret name (<app>-postgrest). Run: ./uis configure postgrest --app <name> --database <name> --schema api_v1 --url-prefix <prefix>"
        if [[ "$json_output" == true ]]; then
            _configure_error "usage" "$service_id" "$msg"
        fi
        log_error "$msg"
        return 1
    fi

    # Defaults (per Decision #16)
    if [[ -z "$database_name" ]]; then
        database_name=$(echo "${app_name}" | tr '-' '_')
    fi
    if [[ -z "$schema" ]]; then
        schema="api_v1"
    fi
    if [[ -z "$url_prefix" ]]; then
        url_prefix="api-${app_name}"
    fi

    # Compute role names (always per-app prefixed; Decision #7)
    local app_user
    app_user=$(echo "${app_name}" | tr '-' '_')
    local web_anon_role="${app_user}_web_anon"
    local authenticator_role="${app_user}_authenticator"
    local secret_name="${app_name}-postgrest"
    local deployment_name="${app_name}-postgrest"

    # Get postgresql admin password
    local admin_pass
    admin_pass=$(_pgrst_get_admin_password)
    if [[ -z "$admin_pass" ]]; then
        if [[ "$json_output" == true ]]; then
            _configure_error "create_resources" "$service_id" "Could not read PGPASSWORD from urbalurba-secrets. Run: uis secrets apply"
        fi
        log_error "Could not read PGPASSWORD from urbalurba-secrets"
        return 1
    fi

    # ---- PURGE PATH (Decision #18) ----
    if [[ "$purge" == "true" ]]; then
        # Refuse if a Deployment still exists — operator must undeploy first
        if _pgrst_deployment_exists "$deployment_name"; then
            local msg="Cannot purge $app_name: Deployment '$deployment_name' still exists in namespace $PGRST_NAMESPACE. Run './uis undeploy postgrest --app $app_name' first."
            if [[ "$json_output" == true ]]; then
                _configure_error "purge" "$service_id" "$msg"
            fi
            log_error "$msg"
            return 1
        fi

        echo "Dropping Postgres roles for app '$app_name'..." >&2
        _pgrst_exec "DROP ROLE IF EXISTS $authenticator_role" "$admin_pass" >/dev/null 2>&1
        _pgrst_exec "DROP ROLE IF EXISTS $web_anon_role" "$admin_pass" >/dev/null 2>&1

        echo "Removing secret '$secret_name' from namespace $PGRST_NAMESPACE..." >&2
        _pgrst_delete_secret "$secret_name"

        if [[ "$json_output" == true ]]; then
            cat <<EOF
{"status":"purged","service":"postgrest","app":"$app_name","roles_dropped":["$authenticator_role","$web_anon_role"],"secret_removed":"$secret_name"}
EOF
        else
            echo ""
            echo "Purged PostgREST configuration for '$app_name':"
            echo "  Dropped roles: $authenticator_role, $web_anon_role"
            echo "  Removed secret: $PGRST_NAMESPACE/$secret_name"
        fi
        return 0
    fi

    # ---- ROTATE PATH (Decision #17) ----
    if [[ "$rotate" == "true" ]]; then
        if ! _pgrst_role_exists "$authenticator_role" "$admin_pass"; then
            local msg="Cannot rotate password for $app_name: role '$authenticator_role' does not exist. Run configure without --rotate first to create it."
            if [[ "$json_output" == true ]]; then
                _configure_error "rotate" "$service_id" "$msg"
            fi
            log_error "$msg"
            return 1
        fi

        echo "WARNING: rotating password for '$authenticator_role' will invalidate the running PostgREST connection pool until the pod is restarted." >&2
        echo "After this completes, run: kubectl rollout restart deployment/$deployment_name -n $PGRST_NAMESPACE" >&2

        local new_password
        new_password=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

        local alter_result
        alter_result=$(_pgrst_exec "ALTER USER $authenticator_role WITH PASSWORD '$new_password'" "$admin_pass" 2>&1)
        if [[ $? -ne 0 ]]; then
            if [[ "$json_output" == true ]]; then
                _configure_error "rotate" "$service_id" "Failed to rotate password for '$authenticator_role': $alter_result"
            fi
            log_error "Failed to rotate password for '$authenticator_role'"
            return 1
        fi

        # Update the secret with the new password
        local db_uri="postgresql://${authenticator_role}:${new_password}@${PG_CLUSTER_HOST}:${PG_INTERNAL_PORT}/${database_name}"
        _pgrst_ensure_namespace "$PGRST_NAMESPACE"
        _pgrst_create_secret "$secret_name" "$db_uri"

        if [[ "$json_output" == true ]]; then
            cat <<EOF
{"status":"rotated","service":"postgrest","app":"$app_name","namespace":"$PGRST_NAMESPACE","secret":"$secret_name","next_step":"kubectl rollout restart deployment/$deployment_name -n $PGRST_NAMESPACE"}
EOF
        else
            echo ""
            echo "Rotated password for '$app_name':"
            echo "  Role: $authenticator_role"
            echo "  Secret: $PGRST_NAMESPACE/$secret_name (key PGRST_DB_URI)"
            echo "  Next step: kubectl rollout restart deployment/$deployment_name -n $PGRST_NAMESPACE"
        fi
        return 0
    fi

    # ---- IDEMPOTENT NO-OP CHECK (Decision #17) ----
    # If both roles AND the secret already exist, treat configure as a no-op.
    if _pgrst_role_exists "$web_anon_role" "$admin_pass" \
        && _pgrst_role_exists "$authenticator_role" "$admin_pass" \
        && _pgrst_secret_exists "$secret_name"; then
        echo "PostgREST already configured for '$app_name' — nothing to do." >&2
        if [[ "$json_output" == true ]]; then
            cat <<EOF
{"status":"already_configured","service":"postgrest","app":"$app_name","namespace":"$PGRST_NAMESPACE","secret":"$secret_name","public_url_prefix":"$url_prefix","next_step":"./uis deploy postgrest --app $app_name"}
EOF
        else
            echo ""
            echo "PostgREST already configured for '$app_name'. To proceed:"
            echo "  ./uis deploy postgrest --app $app_name"
            echo ""
            echo "To rotate the password: ./uis configure postgrest --app $app_name --rotate"
            echo "To remove configuration: ./uis configure postgrest --app $app_name --purge"
        fi
        return 0
    fi

    # ---- CREATE PATH ----
    echo "Configuring PostgREST for app '$app_name'..." >&2
    echo "  Database: $database_name" >&2
    echo "  Schema:   $schema" >&2
    echo "  URL prefix: $url_prefix" >&2

    # Generate password (UIS does not store this; only the secret holds it)
    local app_password
    app_password=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

    # Build the role-creation SQL block (Atlas addendum's ALTER DEFAULT PRIVILEGES included)
    local sql_block
    sql_block=$(cat <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$web_anon_role') THEN
        CREATE ROLE $web_anon_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$authenticator_role') THEN
        CREATE ROLE $authenticator_role LOGIN PASSWORD '$app_password' NOINHERIT;
    ELSE
        ALTER USER $authenticator_role WITH PASSWORD '$app_password';
    END IF;
END
\$\$;
GRANT $web_anon_role TO $authenticator_role;
GRANT USAGE ON SCHEMA $schema TO $web_anon_role;
GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO $web_anon_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO $web_anon_role;
EOF
)

    echo "Creating Postgres roles and grants for app '$app_name'..." >&2
    local sql_result
    sql_result=$(_pgrst_exec "$sql_block" "$admin_pass" 2>&1)
    if [[ $? -ne 0 ]]; then
        if [[ "$json_output" == true ]]; then
            _configure_error "create_resources" "$service_id" "Role creation failed for '$app_name': $sql_result. Likely cause: schema '$schema' does not exist in database '$database_name' (the application must create it before configure runs)."
        fi
        log_error "Role creation failed for '$app_name': $sql_result"
        log_error "Hint: schema '$schema' must exist in database '$database_name' before configure runs (the application's migration creates it)."
        return 1
    fi

    # Ensure the postgrest namespace exists, then write the secret
    echo "Ensuring namespace '$PGRST_NAMESPACE' exists..." >&2
    _pgrst_ensure_namespace "$PGRST_NAMESPACE"

    local db_uri="postgresql://${authenticator_role}:${app_password}@${PG_CLUSTER_HOST}:${PG_INTERNAL_PORT}/${database_name}"
    echo "Writing secret '$secret_name' in namespace $PGRST_NAMESPACE..." >&2
    _pgrst_create_secret "$secret_name" "$db_uri"

    # Output (Decision #20: JSON without credentials; plain output with next-step hint)
    if [[ "$json_output" == true ]]; then
        cat <<EOF
{"status":"ok","service":"postgrest","app":"$app_name","namespace":"$PGRST_NAMESPACE","secret":"$secret_name","in_cluster_url":"http://$deployment_name.$PGRST_NAMESPACE.svc.cluster.local:3000","public_url_prefix":"$url_prefix","next_step":"./uis deploy postgrest --app $app_name"}
EOF
    else
        echo ""
        echo "PostgREST configured for '$app_name':"
        echo "  Database:        $database_name"
        echo "  Schema:          $schema"
        echo "  URL prefix:      $url_prefix"
        echo "  Roles created:   $web_anon_role (NOLOGIN), $authenticator_role (LOGIN NOINHERIT)"
        echo "  Secret:          $PGRST_NAMESPACE/$secret_name (key PGRST_DB_URI)"
        echo ""
        echo "Next step:"
        echo "  ./uis deploy postgrest --app $app_name"
    fi
    return 0
}
