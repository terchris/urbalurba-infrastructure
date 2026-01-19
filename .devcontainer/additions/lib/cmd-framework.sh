#!/bin/bash
#
# cmd-framework.sh - Framework library for cmd-*.sh scripts
#
# Purpose:
#   Provides reusable functions for cmd-*.sh scripts to:
#   - Parse SCRIPT_COMMANDS array entries
#   - Generate help text dynamically
#   - Validate command definitions
#   - Export command metadata as JSON
#
# Usage:
#   source "${SCRIPT_DIR}/lib/cmd-framework.sh"
#
#   # Define SCRIPT_COMMANDS array in your script
#   SCRIPT_COMMANDS=(
#       "Category|--flag|Description|function_name|requires_arg|param_prompt"
#       ...
#   )
#
#   # Generate help text
#   cmd_framework_generate_help SCRIPT_COMMANDS "script-name.sh"
#
#   # Validate commands
#   cmd_framework_validate_commands SCRIPT_COMMANDS
#
# SCRIPT_COMMANDS Array Format (6 fields):
#   Field 1: category      - Menu grouping (e.g., Information, Testing)
#   Field 2: flag          - Command line flag (e.g., --models, --test)
#   Field 3: description   - User-friendly description
#   Field 4: function      - Function name to call
#   Field 5: requires_arg  - true/false - needs parameter?
#   Field 6: param_prompt  - Prompt text for parameter (empty if no param)
#
# Example:
#   "Testing|--test|Test specific model|cmd_test|true|Enter model name"
#
# Author: DevContainer Toolbox Team
# Date: 2025-11-26
#

set -euo pipefail

#------------------------------------------------------------------------------
# Parse a single SCRIPT_COMMANDS array entry
#
# Usage: cmd_framework_parse_command <command_definition>
#
# Arguments:
#   command_definition - Single command entry from SCRIPT_COMMANDS array
#
# Returns: The parsed fields via stdout (pipe-separated)
#   category|flag|description|function|requires_arg|param_prompt
#
# Example:
#   result=$(cmd_framework_parse_command "Testing|--test|Test model|cmd_test|true|Enter model")
#   IFS='|' read -r category flag description function requires_arg param_prompt <<< "$result"
#
#------------------------------------------------------------------------------
cmd_framework_parse_command() {
    local cmd_def="$1"

    # Parse the 6 fields
    IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

    # Return parsed fields (same format)
    echo "$category|$flag|$description|$function|$requires_arg|$param_prompt"
}

#------------------------------------------------------------------------------
# Generate help text from SCRIPT_COMMANDS array
#
# Usage: cmd_framework_generate_help <commands_array_name> <script_name>
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#   script_name        - Name of the script for usage line
#
# Returns: Formatted help text via stdout
#
# Example:
#   SCRIPT_COMMANDS=("Cat1|--cmd1|Desc1|func1|false|" "Cat2|--cmd2|Desc2|func2|true|Enter value")
#   cmd_framework_generate_help SCRIPT_COMMANDS "cmd-ai.sh"
#
# Output:
#   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   Usage: cmd-ai.sh [COMMAND]
#   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#   Cat1 Commands:
#     --cmd1                    Desc1
#
#   Cat2 Commands:
#     --cmd2 <arg>              Desc2
#   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#------------------------------------------------------------------------------
cmd_framework_generate_help() {
    local array_name=$1
    local script_name=$2
    local script_version="${3:-}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Usage: $script_name [COMMAND]"
    [[ -n "$script_version" ]] && echo "Version: $script_version"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local current_category=""

    # Use eval to access the array by name (Bash 3.2 compatible)
    eval "local commands=(\"\${${array_name}[@]}\")"

    for cmd_def in "${commands[@]}"; do
        IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

        # Print category header when category changes
        if [ "$category" != "$current_category" ]; then
            echo ""
            echo "$category Commands:"
            current_category="$category"
        fi

        # Format flag with parameter hint if needed
        local flag_display="$flag"
        if [ "$requires_arg" = "true" ]; then
            flag_display="$flag <arg>"
        fi

        # Print command line (aligned)
        printf "  %-25s %s\n" "$flag_display" "$description"
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

#------------------------------------------------------------------------------
# Validate SCRIPT_COMMANDS array format
#
# Usage: cmd_framework_validate_commands <commands_array_name>
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#
# Returns:
#   Exit code: 0 if all valid, number of errors otherwise
#   Error messages sent to stderr
#
# Validation checks:
#   - Each entry has exactly 6 pipe-separated fields
#   - Flag starts with --
#   - requires_arg is either "true" or "false"
#
# Example:
#   SCRIPT_COMMANDS=("Cat|--cmd|Desc|func|false|")
#   if cmd_framework_validate_commands SCRIPT_COMMANDS; then
#       echo "All commands valid"
#   fi
#
#------------------------------------------------------------------------------
cmd_framework_validate_commands() {
    local array_name=$1
    local errors=0

    # Use eval to access the array by name (Bash 3.2 compatible)
    eval "local commands=(\"\${${array_name}[@]}\")"

    for cmd_def in "${commands[@]}"; do
        # Count fields
        local field_count=$(echo "$cmd_def" | awk -F'|' '{print NF}')

        if [ "$field_count" -ne 6 ]; then
            echo "ERROR: Invalid SCRIPT_COMMANDS entry (expected 6 fields, got $field_count):" >&2
            echo "  $cmd_def" >&2
            ((errors++))
            continue
        fi

        # Parse fields
        IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

        # Validate flag format
        if [[ ! "$flag" =~ ^-- ]]; then
            echo "ERROR: Flag must start with '--': $flag" >&2
            echo "  $cmd_def" >&2
            ((errors++))
        fi

        # Validate requires_arg boolean
        if [[ "$requires_arg" != "true" && "$requires_arg" != "false" ]]; then
            echo "ERROR: requires_arg must be 'true' or 'false': $requires_arg" >&2
            echo "  $cmd_def" >&2
            ((errors++))
        fi

        # Validate param_prompt when requires_arg is true
        if [[ "$requires_arg" = "true" && -z "$param_prompt" ]]; then
            echo "WARNING: requires_arg=true but param_prompt is empty:" >&2
            echo "  $cmd_def" >&2
        fi
    done

    return $errors
}

#------------------------------------------------------------------------------
# Export SCRIPT_COMMANDS array as JSON
#
# Usage: cmd_framework_export_json <commands_array_name>
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#
# Returns: JSON representation via stdout
#
# Example:
#   SCRIPT_COMMANDS=("Cat|--cmd|Desc|func|false|")
#   cmd_framework_export_json SCRIPT_COMMANDS > commands.json
#
# Output:
#   {
#     "commands": [
#       {
#         "category": "Cat",
#         "flag": "--cmd",
#         "description": "Desc",
#         "function": "func",
#         "requires_arg": false,
#         "param_prompt": ""
#       }
#     ]
#   }
#
#------------------------------------------------------------------------------
cmd_framework_export_json() {
    local array_name=$1

    # Use eval to access the array by name (Bash 3.2 compatible)
    eval "local commands=(\"\${${array_name}[@]}\")"

    echo "{"
    echo "  \"commands\": ["

    local first=true
    for cmd_def in "${commands[@]}"; do
        IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

        # Add comma separator for all but first entry
        [ "$first" = false ] && echo ","

        # Convert boolean string to JSON boolean
        local requires_arg_json="false"
        [ "$requires_arg" = "true" ] && requires_arg_json="true"

        # Escape double quotes in strings
        category=$(echo "$category" | sed 's/"/\\"/g')
        flag=$(echo "$flag" | sed 's/"/\\"/g')
        description=$(echo "$description" | sed 's/"/\\"/g')
        function=$(echo "$function" | sed 's/"/\\"/g')
        param_prompt=$(echo "$param_prompt" | sed 's/"/\\"/g')

        # Output JSON object
        cat <<EOF
    {
      "category": "$category",
      "flag": "$flag",
      "description": "$description",
      "function": "$function",
      "requires_arg": $requires_arg_json,
      "param_prompt": "$param_prompt"
    }
EOF
        first=false
    done

    echo ""
    echo "  ]"
    echo "}"
}

#------------------------------------------------------------------------------
# Get all commands for a specific category
#
# Usage: cmd_framework_get_category <commands_array_name> <category_name>
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#   category_name       - Category to filter by
#
# Returns: Matching command entries via stdout (one per line)
#
# Example:
#   SCRIPT_COMMANDS=("Cat1|--cmd1|Desc1|func1|false|" "Cat2|--cmd2|Desc2|func2|true|Enter")
#   cmd_framework_get_category SCRIPT_COMMANDS "Cat1"
#   # Output: Cat1|--cmd1|Desc1|func1|false|
#
#------------------------------------------------------------------------------
cmd_framework_get_category() {
    local array_name=$1
    local target_category=$2

    # Use eval to access the array by name (Bash 3.2 compatible)
    eval "local commands=(\"\${${array_name}[@]}\")"

    for cmd_def in "${commands[@]}"; do
        IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

        if [ "$category" = "$target_category" ]; then
            echo "$cmd_def"
        fi
    done
}

#------------------------------------------------------------------------------
# Get all unique categories from SCRIPT_COMMANDS array
#
# Usage: cmd_framework_get_categories <commands_array_name>
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#
# Returns: List of unique categories via stdout (one per line, in order)
#
# Example:
#   SCRIPT_COMMANDS=("Cat1|--cmd1|Desc1|func1|false|" "Cat2|--cmd2|Desc2|func2|true|Enter")
#   cmd_framework_get_categories SCRIPT_COMMANDS
#   # Output:
#   # Cat1
#   # Cat2
#
#------------------------------------------------------------------------------
cmd_framework_get_categories() {
    local array_name=$1
    local seen_categories=()

    # Use eval to access the array by name (Bash 3.2 compatible)
    eval "local commands=(\"\${${array_name}[@]}\")"

    for cmd_def in "${commands[@]}"; do
        IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

        # Check if category already seen (handle empty array with ${arr[@]+"${arr[@]}"})
        local found=false
        for seen in ${seen_categories[@]+"${seen_categories[@]}"}; do
            if [ "$seen" = "$category" ]; then
                found=true
                break
            fi
        done

        # Output if not seen
        if [ "$found" = false ]; then
            echo "$category"
            seen_categories+=("$category")
        fi
    done
}

#------------------------------------------------------------------------------
# Find command by flag
#
# Usage: cmd_framework_find_command <commands_array_name> <flag>
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#   flag                - Flag to search for (e.g., --test)
#
# Returns: Matching command entry via stdout (empty if not found)
#
# Example:
#   SCRIPT_COMMANDS=("Cat|--test|Test model|cmd_test|true|Enter model")
#   cmd_def=$(cmd_framework_find_command SCRIPT_COMMANDS "--test")
#   # Output: Cat|--test|Test model|cmd_test|true|Enter model
#
#------------------------------------------------------------------------------
cmd_framework_find_command() {
    local array_name=$1
    local target_flag=$2

    # Use eval to access the array by name (Bash 3.2 compatible)
    eval "local commands=(\"\${${array_name}[@]}\")"

    for cmd_def in "${commands[@]}"; do
        IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

        if [ "$flag" = "$target_flag" ]; then
            echo "$cmd_def"
            return 0
        fi
    done

    return 1
}

#------------------------------------------------------------------------------
# Parse command-line arguments and execute commands
#
# Usage: cmd_framework_parse_args <commands_array_name> <script_name> "$@"
#
# Arguments:
#   commands_array_name - Name of the SCRIPT_COMMANDS array variable (passed by name)
#   script_name        - Name of the script (for error messages)
#   $@                 - All command-line arguments passed to the script
#
# Returns: Executes the matched command function
# Exit code: 0 on success, 1 on error
#
# Example in cmd-ai.sh:
#   SCRIPT_COMMANDS=(
#       "Testing|--test|Test model|cmd_test|true|Enter model name"
#       "Info|--models|List models|cmd_models|false|"
#   )
#
#   parse_args() {
#       cmd_framework_parse_args SCRIPT_COMMANDS "cmd-ai.sh" "$@"
#   }
#
#------------------------------------------------------------------------------
cmd_framework_parse_args() {
    local array_name=$1
    local script_name=$2
    shift 2
    local flag="${1:-}"

    # Handle empty argument
    if [ -z "$flag" ]; then
        echo "ERROR: No command specified" >&2
        echo "" >&2
        echo "Use --help for usage information" >&2
        return 1
    fi

    # Handle help flag
    if [ "$flag" = "--help" ] || [ "$flag" = "-h" ]; then
        cmd_framework_generate_help "$array_name" "$script_name"
        return 0
    fi

    # Look up command in SCRIPT_COMMANDS array
    local cmd_def
    if ! cmd_def=$(cmd_framework_find_command "$array_name" "$flag"); then
        echo "ERROR: Unknown command: $flag" >&2
        echo "" >&2
        echo "Use --help for usage information" >&2
        return 1
    fi

    # Parse command definition
    IFS='|' read -r category flag_name description function requires_arg param_prompt <<< "$cmd_def"

    # Check if argument is required
    if [ "$requires_arg" = "true" ]; then
        if [ -z "${2:-}" ]; then
            echo "ERROR: Parameter required for $flag" >&2
            echo "Usage: $script_name $flag <$param_prompt>" >&2
            return 1
        fi
        # Call function with argument
        "$function" "$2"
    else
        # Call function without argument
        "$function"
    fi
}

#------------------------------------------------------------------------------
# Self-test function (if script is run directly)
#------------------------------------------------------------------------------
cmd_framework_self_test() {
    echo "Running cmd-framework.sh self-tests..."
    echo ""

    # Test data
    local TEST_SCRIPT_COMMANDS=(
        "Information|--models|List all models|cmd_models|false|"
        "Information|--info|Show user info|cmd_info|false|"
        "Testing|--test|Test specific model|cmd_test|true|Enter model name"
        "Testing|--test-all|Test all models|cmd_test_all|false|"
    )

    local errors=0

    # Test 1: Parse command
    echo "Test 1: Parse command"
    local result=$(cmd_framework_parse_command "${TEST_SCRIPT_COMMANDS[0]}")
    if [[ "$result" == "Information|--models|List all models|cmd_models|false|" ]]; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL: $result"
        ((errors++))
    fi
    echo ""

    # Test 2: Generate help
    echo "Test 2: Generate help"
    local help_output=$(cmd_framework_generate_help TEST_SCRIPT_COMMANDS "test.sh")
    if [[ "$help_output" == *"Information Commands:"* ]] && [[ "$help_output" == *"Testing Commands:"* ]]; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL: Missing category headers"
        ((errors++))
    fi
    echo ""

    # Test 3: Validate commands
    echo "Test 3: Validate commands"
    if cmd_framework_validate_commands TEST_SCRIPT_COMMANDS 2>/dev/null; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL: Validation failed"
        ((errors++))
    fi
    echo ""

    # Test 4: Invalid command format
    echo "Test 4: Invalid command format (should fail)"
    local INVALID_SCRIPT_COMMANDS=("Cat|--flag|Desc|func")  # Only 4 fields
    if cmd_framework_validate_commands INVALID_SCRIPT_COMMANDS 2>/dev/null; then
        echo "  ❌ FAIL: Should have detected invalid format"
        ((errors++))
    else
        echo "  ✅ PASS: Correctly detected invalid format"
    fi
    echo ""

    # Test 5: Get categories
    echo "Test 5: Get categories"
    local categories=$(cmd_framework_get_categories TEST_SCRIPT_COMMANDS)
    if [[ "$categories" == *"Information"* ]] && [[ "$categories" == *"Testing"* ]]; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL: $categories"
        ((errors++))
    fi
    echo ""

    # Test 6: Find command
    echo "Test 6: Find command by flag"
    local found=$(cmd_framework_find_command TEST_SCRIPT_COMMANDS "--test")
    if [[ "$found" == *"cmd_test"* ]]; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL: $found"
        ((errors++))
    fi
    echo ""

    # Test 7: Export JSON
    echo "Test 7: Export JSON"
    local json_output=$(cmd_framework_export_json TEST_SCRIPT_COMMANDS)
    if [[ "$json_output" == *'"commands":'* ]] && [[ "$json_output" == *'"flag": "--models"'* ]]; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL: Invalid JSON output"
        ((errors++))
    fi
    echo ""

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $errors -eq 0 ]; then
        echo "✅ All tests passed!"
    else
        echo "❌ $errors test(s) failed"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    return $errors
}

#------------------------------------------------------------------------------
# Main (if script run directly with --test flag)
#------------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if [ "${1:-}" = "--test" ]; then
        cmd_framework_self_test
        exit $?
    else
        echo "Usage: $0 --test"
        echo "This is a library file, source it instead of running directly."
        exit 1
    fi
fi
