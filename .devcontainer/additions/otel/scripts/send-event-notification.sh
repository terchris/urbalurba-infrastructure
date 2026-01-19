#!/bin/bash
# file: .devcontainer/additions/otel/scripts/send-event-notification.sh
#
# DESCRIPTION: Generic script to send lifecycle event notifications to OTel collector
# PURPOSE: Centralized notification sending for started, stopped, installed, uninstalled events
#
# Usage:
#   send-event-notification.sh --event-type <type> --message <message> [options]
#
# Examples:
#   # Send startup notification
#   send-event-notification.sh \
#     --event-type "monitoring.started" \
#     --message "Devcontainer monitoring initialized"
#
#   # Send installation notification
#   send-event-notification.sh \
#     --event-type "component.installed" \
#     --message "Python development tools installed" \
#     --component-name "Python" \
#     --category "devcontainer.installation"
#
#   # Send with custom severity
#   send-event-notification.sh \
#     --event-type "service.error" \
#     --message "Failed to start collector" \
#     --severity "ERROR"
#
#------------------------------------------------------------------------------

set -euo pipefail

#------------------------------------------------------------------------------
# DEFAULT VALUES
#------------------------------------------------------------------------------

DEFAULT_SERVICE_NAME="devcontainer-monitor"
DEFAULT_CATEGORY="devcontainer.lifecycle"
DEFAULT_SEVERITY="INFO"
DEFAULT_SEVERITY_NUMBER=9  # INFO level
OTEL_ENDPOINT="http://localhost:4318/v1/logs"
COLLECTOR_VERSION="0.113.0"

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------

EVENT_TYPE=""
MESSAGE=""
SERVICE_NAME="$DEFAULT_SERVICE_NAME"
EVENT_CATEGORY="$DEFAULT_CATEGORY"
SEVERITY="$DEFAULT_SEVERITY"
SEVERITY_NUMBER="$DEFAULT_SEVERITY_NUMBER"
COMPONENT_NAME=""
COMPONENT_VERSION=""
EXTRA_ATTRIBUTES=""
QUIET=false
WAIT_FOR_FLUSH=false

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

show_usage() {
    cat << EOF
Usage: $(basename "$0") --event-type <type> --message <message> [options]

Required Parameters:
  --event-type <type>       Event type (e.g., monitoring.started, component.installed)
  --message <message>       Event message/description

Optional Parameters:
  --service-name <name>     Service name (default: $DEFAULT_SERVICE_NAME)
  --category <category>     Event category (default: $DEFAULT_CATEGORY)
  --severity <level>        Severity level: DEBUG, INFO, WARN, ERROR, FATAL (default: INFO)
  --component-name <name>   Component name (for installation/uninstallation events)
  --component-version <ver> Component version
  --extra-attrs <json>      Additional attributes as JSON object
  --wait-for-flush          Wait 2 seconds after sending for batch flush
  --quiet                   Suppress output messages

Examples:
  # Startup notification
  $(basename "$0") \\
    --event-type "monitoring.started" \\
    --message "Devcontainer monitoring initialized"

  # Installation notification
  $(basename "$0") \\
    --event-type "component.installed" \\
    --message "Go development tools installed" \\
    --component-name "Go" \\
    --component-version "1.21" \\
    --category "devcontainer.installation"

  # Error notification
  $(basename "$0") \\
    --event-type "service.error" \\
    --message "Collector failed to start" \\
    --severity "ERROR"

EOF
}

log_info() {
    if [ "$QUIET" = false ]; then
        echo "ℹ️  $1" >&2
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo "✅ $1" >&2
    fi
}

log_error() {
    echo "❌ $1" >&2
}

get_severity_number() {
    case "$1" in
        DEBUG|TRACE) echo "5" ;;
        INFO) echo "9" ;;
        WARN|WARNING) echo "13" ;;
        ERROR) echo "17" ;;
        FATAL|CRITICAL) echo "21" ;;
        *) echo "9" ;; # Default to INFO
    esac
}

load_identity() {
    # Try to get identity from environment first
    local dev_id="${DEVELOPER_ID:-}"
    local dev_email="${DEVELOPER_EMAIL:-}"
    local project="${PROJECT_NAME:-}"
    local hostname="${TS_HOSTNAME:-}"

    # If not in environment, try loading from identity file
    if [ -z "$dev_id" ] && [ -f "$HOME/.devcontainer-identity" ]; then
        source "$HOME/.devcontainer-identity" 2>/dev/null || true
        dev_id="${DEVELOPER_ID:-unknown}"
        dev_email="${DEVELOPER_EMAIL:-unknown}"
        project="${PROJECT_NAME:-unknown}"
        hostname="${TS_HOSTNAME:-unknown}"
    fi

    # Load git identity (for project/org filtering in reports)
    local git_provider="${GIT_PROVIDER:-}"
    local git_org="${GIT_ORG:-}"
    local git_repo="${GIT_REPO:-}"

    if [ -z "$git_provider" ] && [ -f "$HOME/.git-identity" ]; then
        source "$HOME/.git-identity" 2>/dev/null || true
        git_provider="${GIT_PROVIDER:-}"
        git_org="${GIT_ORG:-}"
        git_repo="${GIT_REPO:-}"
    fi

    # Set defaults if still empty
    dev_id="${dev_id:-unknown}"
    dev_email="${dev_email:-unknown}"
    project="${project:-unknown}"
    hostname="${hostname:-unknown}"
    git_provider="${git_provider:-unknown}"
    git_org="${git_org:-}"
    git_repo="${git_repo:-unknown}"

    # Export for use in JSON template
    export DEVELOPER_ID="$dev_id"
    export DEVELOPER_EMAIL="$dev_email"
    export PROJECT_NAME="$project"
    export TS_HOSTNAME="$hostname"
    export GIT_PROVIDER="$git_provider"
    export GIT_ORG="$git_org"
    export GIT_REPO="$git_repo"
}

build_attributes_json() {
    local attrs=""

    # Always include event_type and event_category
    attrs="${attrs}{\"key\": \"event_type\", \"value\": {\"stringValue\": \"${EVENT_TYPE}\"}},"
    attrs="${attrs}{\"key\": \"event_category\", \"value\": {\"stringValue\": \"${EVENT_CATEGORY}\"}},"
    attrs="${attrs}{\"key\": \"collector_version\", \"value\": {\"stringValue\": \"${COLLECTOR_VERSION}\"}}"

    # Add component info if provided
    if [ -n "$COMPONENT_NAME" ]; then
        attrs="${attrs},{\"key\": \"component_name\", \"value\": {\"stringValue\": \"${COMPONENT_NAME}\"}}"
    fi

    if [ -n "$COMPONENT_VERSION" ]; then
        attrs="${attrs},{\"key\": \"component_version\", \"value\": {\"stringValue\": \"${COMPONENT_VERSION}\"}}"
    fi

    # TODO: Add support for extra attributes from JSON
    # This would require jq or manual JSON parsing

    echo "$attrs"
}

send_notification() {
    log_info "Sending $EVENT_TYPE notification..."

    # Load developer identity
    load_identity

    # Get current timestamp in nanoseconds
    local timestamp_nano
    timestamp_nano=$(date +%s%N)

    # Get severity number
    SEVERITY_NUMBER=$(get_severity_number "$SEVERITY")

    # Build attributes
    local attributes
    attributes=$(build_attributes_json)

    # Send structured log via OTLP
    local response
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$OTEL_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{
            \"resourceLogs\": [{
                \"resource\": {
                    \"attributes\": [
                        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"${SERVICE_NAME}\"}},
                        {\"key\": \"developer_id\", \"value\": {\"stringValue\": \"${DEVELOPER_ID}\"}},
                        {\"key\": \"developer_email\", \"value\": {\"stringValue\": \"${DEVELOPER_EMAIL}\"}},
                        {\"key\": \"project_name\", \"value\": {\"stringValue\": \"${PROJECT_NAME}\"}},
                        {\"key\": \"host_name\", \"value\": {\"stringValue\": \"${TS_HOSTNAME}\"}},
                        {\"key\": \"git.provider\", \"value\": {\"stringValue\": \"${GIT_PROVIDER}\"}},
                        {\"key\": \"git.organization\", \"value\": {\"stringValue\": \"${GIT_ORG}\"}},
                        {\"key\": \"git.repository\", \"value\": {\"stringValue\": \"${GIT_REPO}\"}}
                    ]
                },
                \"scopeLogs\": [{
                    \"logRecords\": [{
                        \"timeUnixNano\": \"${timestamp_nano}\",
                        \"severityText\": \"${SEVERITY}\",
                        \"severityNumber\": ${SEVERITY_NUMBER},
                        \"body\": {\"stringValue\": \"${MESSAGE}\"},
                        \"attributes\": [
                            ${attributes}
                        ]
                    }]
                }]
            }]
        }" 2>&1)

    # Extract HTTP status
    local http_status
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    local response_body
    response_body=$(echo "$response" | grep -v "HTTP_STATUS:")

    # Check response
    if [ "$http_status" = "200" ] || echo "$response_body" | grep -q "partialSuccess"; then
        log_success "Event notification sent successfully"

        # Wait for batch flush if requested
        if [ "$WAIT_FOR_FLUSH" = true ]; then
            sleep 2
        fi

        return 0
    else
        log_error "Event notification may have failed (HTTP $http_status)"
        if [ "$QUIET" = false ]; then
            echo "Response: $response_body" >&2
        fi
        return 1
    fi
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

parse_arguments() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --event-type)
                EVENT_TYPE="$2"
                shift 2
                ;;
            --message)
                MESSAGE="$2"
                shift 2
                ;;
            --service-name)
                SERVICE_NAME="$2"
                shift 2
                ;;
            --category)
                EVENT_CATEGORY="$2"
                shift 2
                ;;
            --severity)
                SEVERITY="$2"
                shift 2
                ;;
            --component-name)
                COMPONENT_NAME="$2"
                shift 2
                ;;
            --component-version)
                COMPONENT_VERSION="$2"
                shift 2
                ;;
            --extra-attrs)
                EXTRA_ATTRIBUTES="$2"
                shift 2
                ;;
            --wait-for-flush)
                WAIT_FOR_FLUSH=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [ -z "$EVENT_TYPE" ]; then
        log_error "Missing required parameter: --event-type"
        show_usage
        exit 1
    fi

    if [ -z "$MESSAGE" ]; then
        log_error "Missing required parameter: --message"
        show_usage
        exit 1
    fi
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    parse_arguments "$@"
    send_notification
}

# Run main function
main "$@"
