#!/bin/bash
# File: .devcontainer/additions/cmd-ai.sh
#
# Usage:
#   cmd-ai.sh --models           # List all models you have access to
#   cmd-ai.sh --spend            # Show current month spending
#   cmd-ai.sh --budget           # Show budget status
#   cmd-ai.sh --help             # Show all commands
#
# Purpose:
#   Developer commands for LiteLLM usage, models, and spending
#   Flag-based interface (no interactive menu)
#
# Author: Terje Christensen
# Created: November 2024
#
#------------------------------------------------------------------------------
# SCRIPT METADATA - For dev-setup.sh discovery
#------------------------------------------------------------------------------

SCRIPT_ID="cmd-ai"  # Unique identifier (must match filename without .sh)
SCRIPT_NAME="AI Management"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="Manage AI models, spending, and usage through LiteLLM"
SCRIPT_CATEGORY="AI_TOOLS"
SCRIPT_PREREQUISITES="config-ai-claudecode.sh"

#------------------------------------------------------------------------------
# COMMAND DEFINITIONS - Single source of truth
#------------------------------------------------------------------------------

# Format: category|flag|description|function|requires_arg|param_prompt
SCRIPT_COMMANDS=(
    "Information|--models|List all models you have access to|cmd_models|false|"
    "Information|--info|Show user info (teams, budgets)|cmd_info|false|"
    "Information|--budget|Show budget status with usage percentage|cmd_budget|false|"
    "Information|--keys|List your API keys and spending|cmd_keys|false|"
    "Spending|--spend|Show spending summary (current month)|cmd_spend|false|"
    "Spending|--spend-week|Last 7 days spending|cmd_spend_week|false|"
    "Spending|--spend-month|Last 30 days spending|cmd_spend_month|false|"
    "Spending|--spend-today|Today's spending|cmd_spend_today|false|"
    "Spending|--activity|Detailed breakdown by model and date|cmd_activity|false|"
    "Analysis|--top-models|Models ranked by usage and spending|cmd_top_models|false|"
    "Analysis|--daily|Daily spending trend (current month)|cmd_daily|false|"
    "Testing|--test|Test access to specific model|cmd_test|true|Enter model name"
    "Testing|--test-all|Test access to all models|cmd_test_all|false|"
    "Testing|--health|Check LiteLLM connectivity|cmd_health|false|"
)

#------------------------------------------------------------------------------

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/utilities.sh"

# Configuration
LITELLM_URL="${LITELLM_URL:-http://localhost:8080}"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

check_prerequisites() {
    local skip_auth="${1:-false}"
    local errors=0

    log_info "Checking prerequisites..."

    # Check auth token (skip for health check)
    if [ "$skip_auth" != "true" ]; then
        if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
            log_error "ANTHROPIC_AUTH_TOKEN not set"
            log_info "Fix: bash ${SCRIPT_DIR}/config-ai-claudecode.sh"
            errors=1
        fi
    fi

    # Check jq (required for JSON parsing)
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq not installed (required for JSON parsing)"
        log_info "Fix: sudo apt-get install jq"
        errors=1
    fi

    # Check LiteLLM accessibility (any response is OK, even 401)
    local health_response
    health_response=$(curl -s -w "%{http_code}" "${LITELLM_URL}/health" -o /dev/null)
    if [ -z "$health_response" ] || [ "$health_response" = "000" ]; then
        log_warning "Cannot reach LiteLLM at ${LITELLM_URL}"
        log_info "Check nginx: ps aux | grep nginx"
        log_info "Check port: ss -tunlp | grep 8080"
        errors=1
    fi

    if [ $errors -eq 1 ]; then
        echo ""
        log_error "Prerequisites not met. Please fix the issues above."
        return 1
    fi

    log_success "Prerequisites OK"
    echo ""
    return 0
}

call_litellm_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"

    local url="${LITELLM_URL}${endpoint}"

    # Timeout settings:
    # - connect-timeout: 10s to establish connection
    # - max-time: 120s for total operation (Ollama models can be slow on first load)
    if [ "$method" = "GET" ]; then
        curl -s --connect-timeout 10 --max-time 30 \
            -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" \
            "$url"
    elif [ "$method" = "POST" ]; then
        curl -s --connect-timeout 10 --max-time 120 \
            -X POST "$url" \
            -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

# Display user information in standard format (for helpdesk reference)
display_user_info() {
    local response="$1"
    local user_id
    local user_alias

    user_id=$(echo "$response" | jq -r '.user_id // "N/A"')
    user_alias=$(echo "$response" | jq -r '.user_info.user_alias // .user_alias // "N/A"')

    echo "User ID:    $user_id"
    echo "Name:       $user_alias"
    echo ""
}

#------------------------------------------------------------------------------
# Command Functions - Information
#------------------------------------------------------------------------------

cmd_models() {
    echo "════════════════════════════════════════════════════════"
    echo "🤖 Your Available Models"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local response
    response=$(call_litellm_api "/v1/models")

    if [ -z "$response" ]; then
        log_error "Failed to fetch models"
        return 1
    fi

    local models
    models=$(echo "$response" | jq -r '.data[]?.id // empty' 2>/dev/null)

    if [ -z "$models" ]; then
        log_warning "No models available with your API key"
        return 0
    fi

    local count=0
    while IFS= read -r model; do
        echo "✓ $model"
        count=$((count + 1))
    done <<< "$models"

    echo "════════════════════════════════════════════════════════"
    echo "Total: $count models available to you"
    echo ""
    log_info "Note: Other models may exist in LiteLLM but not accessible with your key"
    echo ""
}

cmd_info() {
    echo "════════════════════════════════════════════════════════"
    echo "👤 User Information"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local response
    response=$(call_litellm_api "/user/info")

    if [ -z "$response" ]; then
        log_error "Failed to fetch user info"
        return 1
    fi

    display_user_info "$response"

    # Show teams
    local teams
    teams=$(echo "$response" | jq -r '.teams[]? | .team_alias // "N/A"' 2>/dev/null)

    if [ -n "$teams" ]; then
        echo "Teams:"
        while IFS= read -r team; do
            echo "  • $team"

            # Get team models
            local team_models
            team_models=$(echo "$response" | jq -r ".teams[] | select(.team_alias==\"$team\") | .models[]? // empty" 2>/dev/null)

            if [ -n "$team_models" ]; then
                echo "    Models:"
                while IFS= read -r model; do
                    echo "      - $model"
                done <<< "$team_models"
            fi
        done <<< "$teams"
    fi

    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_budget() {
    echo "════════════════════════════════════════════════════════"
    echo "💵 Your Budget Status"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local response
    response=$(call_litellm_api "/user/info")

    if [ -z "$response" ]; then
        log_error "Failed to fetch budget info"
        return 1
    fi

    display_user_info "$response"

    local budget
    local spend
    budget=$(echo "$response" | jq -r '.max_budget // 0')
    spend=$(echo "$response" | jq -r '.spend // 0')

    if [ "$budget" != "null" ] && [ "$budget" != "0" ]; then
        local remaining
        local percent
        remaining=$(echo "$budget - $spend" | bc)
        percent=$(echo "scale=1; ($spend / $budget) * 100" | bc)

        echo "Budget:     $(format_currency "$budget")"
        echo "Spent:      $(format_currency "$spend")"
        echo "Remaining:  $(format_currency "$remaining")"
        echo "Used:       ${percent}%"

        # Simple progress bar
        local filled
        filled=$(echo "scale=0; $percent / 5" | bc)
        local bar=""
        for ((i=0; i<20; i++)); do
            if [ "$i" -lt "${filled%.*}" ]; then
                bar="${bar}█"
            else
                bar="${bar}░"
            fi
        done
        echo "            $bar"

        # Warning if over 80%
        if (( $(echo "$percent > 80" | bc -l) )); then
            echo ""
            log_warning "You have used more than 80% of your budget"
        fi
    else
        echo "Budget:     Unlimited"
        echo "Spent:      $(format_currency "$spend")"
    fi

    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_keys() {
    echo "════════════════════════════════════════════════════════"
    echo "🔑 API Keys"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local response
    response=$(call_litellm_api "/user/info")

    if [ -z "$response" ]; then
        log_error "Failed to fetch keys"
        return 1
    fi

    display_user_info "$response"

    local keys
    keys=$(echo "$response" | jq -r '.teams[]?.keys[]? | "\(.key_alias // "N/A")|\(.key_name // "N/A")|\(.spend // 0)"' 2>/dev/null)

    if [ -z "$keys" ]; then
        log_warning "No keys found"
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    printf "%-30s %-20s %s\n" "Key alias name" "Key" "Spend"
    printf "%-30s %-20s %s\n" "--------------" "---" "-----"

    while IFS='|' read -r alias key spend; do
        printf "%-30s %-20s %s\n" "$alias" "$key" "$(format_currency "$spend")"
    done <<< "$keys"

    echo "════════════════════════════════════════════════════════"
    echo ""
}

#------------------------------------------------------------------------------
# Command Functions - Spending
#------------------------------------------------------------------------------

cmd_spend() {
    cmd_spend_generic "month" "Current Month"
}

cmd_spend_week() {
    cmd_spend_generic "week" "Last 7 Days"
}

cmd_spend_month() {
    cmd_spend_generic "30days" "Last 30 Days"
}

cmd_spend_today() {
    cmd_spend_generic "today" "Today"
}

cmd_spend_generic() {
    local range="$1"
    local title="$2"

    echo "════════════════════════════════════════════════════════"
    echo "💰 Your Spending Summary ($title)"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Get user info first for display
    local user_response
    user_response=$(call_litellm_api "/user/info")
    if [ -n "$user_response" ]; then
        display_user_info "$user_response"
    fi

    local dates
    dates=$(get_date_range "$range")
    local start_date
    local end_date
    read -r start_date end_date <<< "$dates"

    echo "Period:         $start_date to $end_date"

    local response
    response=$(call_litellm_api "/user/daily/activity?start_date=$start_date&end_date=$end_date")

    if [ -z "$response" ]; then
        log_error "Failed to fetch spending data"
        return 1
    fi

    local total_spend
    local total_requests
    local total_tokens
    local success_requests
    local failed_requests

    total_spend=$(echo "$response" | jq -r '.metadata.total_spend // 0')
    total_requests=$(echo "$response" | jq -r '.metadata.total_api_requests // 0')
    total_tokens=$(echo "$response" | jq -r '.metadata.total_tokens // 0')
    success_requests=$(echo "$response" | jq -r '.metadata.total_successful_requests // 0')
    failed_requests=$(echo "$response" | jq -r '.metadata.total_failed_requests // 0')

    echo "Total Spend:    $(format_currency "$total_spend")"
    echo "Requests:       $(format_number "$total_requests") ($success_requests successful, $failed_requests failed)"
    echo "Tokens:         $(format_number "$total_tokens") total"

    echo "════════════════════════════════════════════════════════"
    echo ""
    log_info "Note: Spending shown is for your API key only"
    echo ""
}

cmd_activity() {
    echo "════════════════════════════════════════════════════════"
    echo "📊 Your Detailed Activity Breakdown"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Get user info first for display
    local user_response
    user_response=$(call_litellm_api "/user/info")
    if [ -n "$user_response" ]; then
        display_user_info "$user_response"
    fi

    local dates
    dates=$(get_date_range "month")
    local start_date
    local end_date
    read -r start_date end_date <<< "$dates"

    echo "Period:         $start_date to $end_date"
    echo ""

    local response
    response=$(call_litellm_api "/user/daily/activity?start_date=$start_date&end_date=$end_date")

    if [ -z "$response" ]; then
        log_error "Failed to fetch activity data"
        return 1
    fi

    local results
    results=$(echo "$response" | jq -r '.results[]? | "\(.date // "N/A")|\(.model // "N/A")|\(.spend // 0)|\(.api_requests // 0)|\(.total_tokens // 0)"' 2>/dev/null)

    if [ -z "$results" ]; then
        log_warning "No activity data found"
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    printf "%-12s %-35s %10s %10s %12s\n" "Date" "Model" "Spend" "Requests" "Tokens"
    printf "%-12s %-35s %10s %10s %12s\n" "----" "-----" "-----" "--------" "------"

    while IFS='|' read -r date model spend requests tokens; do
        printf "%-12s %-35s %10s %10s %12s\n" \
            "$date" \
            "${model:0:35}" \
            "$(format_currency "$spend")" \
            "$requests" \
            "$(format_number "$tokens")"
    done <<< "$results"

    echo "════════════════════════════════════════════════════════"
    echo ""
}

#------------------------------------------------------------------------------
# Command Functions - Analysis
#------------------------------------------------------------------------------

cmd_top_models() {
    echo "════════════════════════════════════════════════════════"
    echo "🏆 Your Top Models by Usage"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Get user info first for display
    local user_response
    user_response=$(call_litellm_api "/user/info")
    if [ -n "$user_response" ]; then
        display_user_info "$user_response"
    fi

    local dates
    dates=$(get_date_range "month")
    local start_date
    local end_date
    read -r start_date end_date <<< "$dates"

    echo "Period:         $start_date to $end_date"
    echo ""

    local response
    response=$(call_litellm_api "/user/daily/activity?start_date=$start_date&end_date=$end_date")

    if [ -z "$response" ]; then
        log_error "Failed to fetch activity data"
        return 1
    fi

    # Group by model and sum spend/requests
    local grouped
    grouped=$(echo "$response" | jq -r '
        [.results[]? | {model: .model, spend: .spend, requests: .api_requests}] |
        group_by(.model) |
        map({
            model: .[0].model,
            total_spend: (map(.spend) | add),
            total_requests: (map(.requests) | add)
        }) |
        sort_by(-.total_spend) |
        .[] | "\(.model)|\(.total_spend // 0)|\(.total_requests // 0)"
    ' 2>/dev/null)

    if [ -z "$grouped" ]; then
        log_warning "No usage data found"
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    printf "%-40s %12s %12s\n" "Model" "Total Spend" "Requests"
    printf "%-40s %12s %12s\n" "-----" "-----------" "--------"

    while IFS='|' read -r model spend requests; do
        printf "%-40s %12s %12s\n" \
            "${model:0:40}" \
            "$(format_currency "$spend")" \
            "$(format_number "$requests")"
    done <<< "$grouped"

    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_daily() {
    echo "════════════════════════════════════════════════════════"
    echo "📈 Your Daily Spending Trend"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Get user info first for display
    local user_response
    user_response=$(call_litellm_api "/user/info")
    if [ -n "$user_response" ]; then
        display_user_info "$user_response"
    fi

    local dates
    dates=$(get_date_range "month")
    local start_date
    local end_date
    read -r start_date end_date <<< "$dates"

    echo "Period:         $start_date to $end_date"
    echo ""

    local response
    response=$(call_litellm_api "/user/daily/activity?start_date=$start_date&end_date=$end_date")

    if [ -z "$response" ]; then
        log_error "Failed to fetch activity data"
        return 1
    fi

    # Group by date and sum spend
    local daily
    daily=$(echo "$response" | jq -r '
        [.results[]? | {date: .date, spend: .spend}] |
        group_by(.date) |
        map({
            date: .[0].date,
            total_spend: (map(.spend) | add)
        }) |
        sort_by(.date) |
        .[] | "\(.date)|\(.total_spend // 0)"
    ' 2>/dev/null)

    if [ -z "$daily" ]; then
        log_warning "No daily data found"
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    printf "%-12s %12s\n" "Date" "Spend"
    printf "%-12s %12s\n" "----" "-----"

    while IFS='|' read -r date spend; do
        printf "%-12s %12s\n" "$date" "$(format_currency "$spend")"
    done <<< "$daily"

    echo "════════════════════════════════════════════════════════"
    echo ""
}

#------------------------------------------------------------------------------
# Command Functions - Testing
#------------------------------------------------------------------------------

cmd_test() {
    local model="$1"

    echo "════════════════════════════════════════════════════════"
    echo "🧪 Testing Model Access: $model"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Get user info first for display
    local user_response
    user_response=$(call_litellm_api "/user/info")
    if [ -n "$user_response" ]; then
        display_user_info "$user_response"
    fi

    echo "Testing model with prompt: 'Say hello in 3 words'"
    echo ""

    local data
    data=$(cat <<EOF
{
    "model": "$model",
    "messages": [{"role": "user", "content": "Say hello in 3 words"}],
    "max_tokens": 20
}
EOF
)

    local response
    response=$(call_litellm_api "/v1/chat/completions" "POST" "$data")

    if [ -z "$response" ]; then
        log_error "Failed to test model - No response received"
        echo ""
        echo "Possible causes:"
        echo "  • Connection timeout (model may be slow to load)"
        echo "  • LiteLLM service not responding"
        echo "  • Network connectivity issue"
        echo ""
        echo "Tip: Ollama models can take 30-60 seconds on first request while loading"
        echo "      Try running the test again if it's the first time."
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 1
    fi

    # Check for error
    local error
    error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)

    if [ -n "$error" ]; then
        log_error "Model test failed"
        echo ""
        echo "Error details:"
        echo "$error"
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 1
    fi

    # Check response content
    local content
    content=$(echo "$response" | jq -r '.choices[0]?.message?.content // empty' 2>/dev/null)

    if [ -n "$content" ] && [ "$content" != "null" ] && [ "$content" != "" ]; then
        log_success "Model test passed - Model is working correctly"
        echo ""
        echo "Model response: \"$content\""
    else
        log_warning "Model test inconclusive - No response received"
        echo ""
        echo "The model accepted the request but returned no content."
        echo "This could indicate a configuration issue with the model."
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_test_all() {
    echo "════════════════════════════════════════════════════════"
    echo "🧪 Testing All Models"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Get user info first for display
    local user_response
    user_response=$(call_litellm_api "/user/info")
    if [ -n "$user_response" ]; then
        display_user_info "$user_response"
    fi

    # Get models
    local response
    response=$(call_litellm_api "/v1/models")

    if [ -z "$response" ]; then
        log_error "Failed to fetch models"
        return 1
    fi

    local models
    models=$(echo "$response" | jq -r '.data[]?.id // empty' 2>/dev/null)

    if [ -z "$models" ]; then
        log_warning "No models found"
        return 0
    fi

    printf "%-40s %s\n" "Model" "Status"
    printf "%-40s %s\n" "-----" "------"

    while IFS= read -r model; do
        local data
        data=$(cat <<EOF
{
    "model": "$model",
    "messages": [{"role": "user", "content": "Say hello in 3 words"}],
    "max_tokens": 20
}
EOF
)

        # Add timeout to prevent hanging on slow models (10 second timeout)
        # Use || true to prevent curl timeout from exiting script due to set -e
        local test_response
        test_response=$(curl -s --max-time 10 -X POST "${LITELLM_URL}/v1/chat/completions" \
            -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null || true)

        if [ -z "$test_response" ]; then
            printf "%-40s ⏱️  Timeout\n" "${model:0:40}"
            continue
        fi

        local error
        error=$(echo "$test_response" | jq -r '.error.message // empty' 2>/dev/null)

        if [ -n "$error" ]; then
            printf "%-40s ❌ FAILED\n" "${model:0:40}"
            # Show the error reason (critical for debugging - e.g., lack of credits)
            echo "    └─ Error: $error"
        else
            # Check if we actually got content back
            local test_content
            test_content=$(echo "$test_response" | jq -r '.choices[0]?.message?.content // empty' 2>/dev/null)

            if [ -n "$test_content" ] && [ "$test_content" != "null" ]; then
                printf "%-40s ✅ OK\n" "${model:0:40}"
            else
                printf "%-40s ⚠️  WARNING\n" "${model:0:40}"
                echo "    └─ No response content (model accessible but not responding)"
            fi
        fi
    done <<< "$models"

    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "💡 Budget Information"
    echo "────────────────────────────────────────────────────────"

    # Show user's LiteLLM budget status
    if [ -n "$user_response" ]; then
        local user_budget
        local user_spend
        user_budget=$(echo "$user_response" | jq -r '.max_budget // "null"')
        user_spend=$(echo "$user_response" | jq -r '.spend // 0')

        if [ "$user_budget" = "null" ] || [ "$user_budget" = "0" ]; then
            echo "Your LiteLLM budget: Unlimited (Spent: $(format_currency "$user_spend"))"
        else
            echo "Your LiteLLM budget: $(format_currency "$user_spend") of $(format_currency "$user_budget") used"
        fi
    fi

    echo ""
    echo "Note: Model failures can be caused by:"
    echo "  • Anthropic credits exhausted → Contact admin to add credits to Anthropic account"
    echo "  • LiteLLM budget limit reached → Contact admin to increase your spending limit"
    echo "  • Model access denied → Contact admin to grant model permissions"
    echo "  • Network/timeout issues → Check connectivity or try again"

    echo "════════════════════════════════════════════════════════"
    echo ""
}

cmd_health() {
    echo "════════════════════════════════════════════════════════"
    echo "🏥 LiteLLM Health Check"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local start_time
    start_time=$(date +%s%N)

    # Simple connectivity check - don't need full health details
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o /dev/null "${LITELLM_URL}/health")

    local end_time
    end_time=$(date +%s%N)

    local duration_ms
    duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
        log_error "Cannot reach LiteLLM"
        echo "URL: $LITELLM_URL"
        echo ""
        echo "Troubleshooting:"
        echo "  • Check nginx: ps aux | grep nginx"
        echo "  • Check port: ss -tunlp | grep 8080"
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo ""
        return 1
    fi

    # Check response status
    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        log_success "LiteLLM is reachable"
    else
        log_warning "LiteLLM responded with HTTP $http_code"
    fi

    echo "URL:           $LITELLM_URL"
    echo "Response time: ${duration_ms}ms"
    echo "HTTP Status:   $http_code"

    echo "════════════════════════════════════════════════════════"
    echo ""
}

#------------------------------------------------------------------------------
# Command-Line Parser
#------------------------------------------------------------------------------

show_help() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_generate_help >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Generate help from SCRIPT_COMMANDS array (pass version as 3rd argument)
    cmd_framework_generate_help SCRIPT_COMMANDS "cmd-ai.sh" "$SCRIPT_VER"

    # Add examples section
    echo ""
    echo "Examples:"
    echo "  cmd-ai.sh --models                        # List models"
    echo "  cmd-ai.sh --spend                         # This month's spending"
    echo "  cmd-ai.sh --test claude-sonnet-4-5        # Test specific model"
    echo "  cmd-ai.sh --test qwen2.5-coder:7b         # Test Ollama model"
    echo ""
}

parse_args() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_parse_args >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Use framework to parse arguments
    cmd_framework_parse_args SCRIPT_COMMANDS "cmd-ai.sh" "$@"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    # Show help without checking prerequisites
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_help
        exit 0
    fi

    # Health check needs relaxed prerequisites (no auth token required)
    if [ "${1:-}" = "--health" ]; then
        check_prerequisites "true" || exit 1
        cmd_health
        exit 0
    fi

    # Check prerequisites for all other commands
    check_prerequisites || exit 1

    # Parse and execute command
    parse_args "$@"
}

# Run main function
main "$@"
