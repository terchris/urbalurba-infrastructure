#!/bin/bash
# File: .devcontainer/manage/dev-template.sh
# Description: Template initializer for the Urbalurba Developer Platform with dialog menu.
#              Reads TEMPLATE_INFO from each template for display names and descriptions.
#
# Usage: ./dev-template.sh [template-directory-name]
#
# Examples:
#   ./dev-template.sh                      # Show menu
#   ./dev-template.sh typescript-basic-webserver  # Direct selection
#
# Version: 1.3.0
#------------------------------------------------------------------------------
set -e

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-template"
SCRIPT_NAME="Templates"
SCRIPT_DESCRIPTION="Create project files from templates"
SCRIPT_CATEGORY="SYSTEM_COMMANDS"
SCRIPT_CHECK_COMMAND="true"
SCRIPT_VERSION="1.3.0"

#------------------------------------------------------------------------------
# Check if dialog is available
#------------------------------------------------------------------------------
function check_dialog() {
  if ! command -v dialog >/dev/null 2>&1; then
    echo "❌ Error: dialog is not installed"
    echo "   sudo apt-get install dialog"
    exit 2
  fi
}

#------------------------------------------------------------------------------
# Display banner
#------------------------------------------------------------------------------
function display_intro() {
  echo ""
  echo "🛠️  Urbalurba Developer Platform - Project Template Initializer"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

#------------------------------------------------------------------------------
# Detect GitHub repository info
#------------------------------------------------------------------------------
function detect_github_info() {
  echo "🔍 Detecting GitHub repository information..."
  GITHUB_REMOTE=$(git remote get-url origin 2>/dev/null)
  
  if [[ -z "$GITHUB_REMOTE" ]]; then
    echo "❌ Could not determine GitHub remote"
    exit 1
  fi
  
  GITHUB_USERNAME=$(echo "$GITHUB_REMOTE" | sed -n 's/.*github.com[:/]\(.*\)\/.*/\1/p')
  REPO_NAME=$(basename -s .git "$GITHUB_REMOTE")

  if [[ -z "$GITHUB_USERNAME" || -z "$REPO_NAME" ]]; then
    echo "❌ Could not determine GitHub username or repo name"
    exit 1
  fi

  echo "✅ GitHub user: $GITHUB_USERNAME"
  echo "✅ Repository: $REPO_NAME"
  echo ""
}

#------------------------------------------------------------------------------
# Clone templates repository
#------------------------------------------------------------------------------
function clone_template_repo() {
  TEMPLATE_OWNER="terchris"
  TEMPLATE_REPO_NAME="urbalurba-dev-templates"
  TEMPLATE_REPO_URL="https://github.com/$TEMPLATE_OWNER/$TEMPLATE_REPO_NAME"

  TEMP_DIR=$(mktemp -d)
  echo "📥 Fetching latest templates from GitHub..."
  echo "   📁 Download location: $TEMP_DIR"
  echo ""
  cd "$TEMP_DIR"

  if ! git clone --quiet $TEMPLATE_REPO_URL 2>/dev/null; then
    echo "❌ Failed to clone template repository"
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  if [ ! -d "$TEMPLATE_REPO_NAME/templates" ]; then
    echo "❌ Templates directory not found"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  echo "✅ Templates fetched successfully"
  echo ""
}

#------------------------------------------------------------------------------
# Read TEMPLATE_INFO from template directory
#------------------------------------------------------------------------------
function read_template_info() {
  local template_dir="$1"
  local info_file="$template_dir/TEMPLATE_INFO"
  
  # Defaults
  INFO_NAME=$(basename "$template_dir")
  INFO_DESCRIPTION="No description"
  INFO_CATEGORY="UNCATEGORIZED"
  INFO_PURPOSE=""
  
  if [ -f "$info_file" ]; then
    # Unset variables to avoid pollution
    unset TEMPLATE_NAME TEMPLATE_DESCRIPTION TEMPLATE_CATEGORY TEMPLATE_PURPOSE
    
    source "$info_file"
    
    INFO_NAME="${TEMPLATE_NAME:-$INFO_NAME}"
    INFO_DESCRIPTION="${TEMPLATE_DESCRIPTION:-$INFO_DESCRIPTION}"
    INFO_CATEGORY="${TEMPLATE_CATEGORY:-$INFO_CATEGORY}"
    INFO_PURPOSE="${TEMPLATE_PURPOSE:-$INFO_PURPOSE}"
    
    # Clean up after sourcing
    unset TEMPLATE_NAME TEMPLATE_DESCRIPTION TEMPLATE_CATEGORY TEMPLATE_PURPOSE
  fi
}

#------------------------------------------------------------------------------
# Scan templates and build arrays
#------------------------------------------------------------------------------
function scan_templates() {
  TEMPLATE_DIRS=()
  TEMPLATE_NAMES=()
  TEMPLATE_DESCRIPTIONS=()
  TEMPLATE_CATEGORIES=()
  TEMPLATE_PURPOSES=()
  
  # Group by category
  declare -g -A CATEGORY_WEB_SERVER
  declare -g -A CATEGORY_WEB_APP
  declare -g -A CATEGORY_OTHER
  
  echo "📋 Scanning available templates..."
  for dir in "$TEMPLATE_REPO_NAME/templates"/*; do
    if [ -d "$dir" ]; then
      read_template_info "$dir"
      
      local idx=${#TEMPLATE_DIRS[@]}
      TEMPLATE_DIRS+=("$(basename "$dir")")
      TEMPLATE_NAMES+=("$INFO_NAME")
      TEMPLATE_DESCRIPTIONS+=("$INFO_DESCRIPTION")
      TEMPLATE_CATEGORIES+=("$INFO_CATEGORY")
      TEMPLATE_PURPOSES+=("$INFO_PURPOSE")
      
      # Group by category for menu display
      case "$INFO_CATEGORY" in
        WEB_SERVER)
          CATEGORY_WEB_SERVER["$(basename "$dir")"]=$idx
          ;;
        WEB_APP)
          CATEGORY_WEB_APP["$(basename "$dir")"]=$idx
          ;;
        *)
          CATEGORY_OTHER["$(basename "$dir")"]=$idx
          ;;
      esac
    fi
  done
  
  if [ ${#TEMPLATE_DIRS[@]} -eq 0 ]; then
    echo "❌ No templates found"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  echo "✅ Found ${#TEMPLATE_DIRS[@]} template(s)"
  echo ""
}

#------------------------------------------------------------------------------
# Show dialog menu grouped by category and get selection
#------------------------------------------------------------------------------
function show_template_menu() {
  local menu_options=()
  local option_num=1
  declare -g -A MENU_TO_INDEX
  
  # Web Server templates
  if [ ${#CATEGORY_WEB_SERVER[@]} -gt 0 ]; then
    for dir_name in $(printf '%s\n' "${!CATEGORY_WEB_SERVER[@]}" | sort); do
      local idx=${CATEGORY_WEB_SERVER[$dir_name]}
      menu_options+=("$option_num" "🌐 ${TEMPLATE_NAMES[$idx]}" "${TEMPLATE_DESCRIPTIONS[$idx]}")
      MENU_TO_INDEX[$option_num]=$idx
      ((option_num++))
    done
  fi
  
  # Web App templates
  if [ ${#CATEGORY_WEB_APP[@]} -gt 0 ]; then
    for dir_name in $(printf '%s\n' "${!CATEGORY_WEB_APP[@]}" | sort); do
      local idx=${CATEGORY_WEB_APP[$dir_name]}
      menu_options+=("$option_num" "📱 ${TEMPLATE_NAMES[$idx]}" "${TEMPLATE_DESCRIPTIONS[$idx]}")
      MENU_TO_INDEX[$option_num]=$idx
      ((option_num++))
    done
  fi
  
  # Other templates
  if [ ${#CATEGORY_OTHER[@]} -gt 0 ]; then
    for dir_name in $(printf '%s\n' "${!CATEGORY_OTHER[@]}" | sort); do
      local idx=${CATEGORY_OTHER[$dir_name]}
      menu_options+=("$option_num" "📦 ${TEMPLATE_NAMES[$idx]}" "${TEMPLATE_DESCRIPTIONS[$idx]}")
      MENU_TO_INDEX[$option_num]=$idx
      ((option_num++))
    done
  fi
  
  local choice
  choice=$(dialog --clear \
    --item-help \
    --title "Project Templates" \
    --menu "Choose a template (ESC to cancel):\n\n🌐=Web Server  📱=Web App  📦=Other" \
    20 80 12 \
    "${menu_options[@]}" \
    2>&1 >/dev/tty)
  
  if [[ $? -ne 0 ]]; then
    clear
    echo "ℹ️  Selection cancelled"
    rm -rf "$TEMP_DIR"
    exit 3
  fi
  
  echo "$choice"
}

#------------------------------------------------------------------------------
# Show template details confirmation dialog
#------------------------------------------------------------------------------
function show_template_details() {
  local idx=$1
  local template_name="${TEMPLATE_NAMES[$idx]}"
  local template_desc="${TEMPLATE_DESCRIPTIONS[$idx]}"
  local template_category="${TEMPLATE_CATEGORIES[$idx]}"
  local template_purpose="${TEMPLATE_PURPOSES[$idx]}"
  
  # Build details text
  local details=""
  details+="Name: $template_name\n\n"
  details+="Category: $template_category\n\n"
  details+="Description:\n$template_desc\n\n"
  
  if [ -n "$template_purpose" ]; then
    details+="Purpose:\n$template_purpose\n\n"
  fi
  
  details+="Directory: ${TEMPLATE_DIRS[$idx]}"
  
  # Show confirmation dialog
  dialog --clear \
    --title "Template Details" \
    --yesno "$details\n\nDo you want to use this template?" \
    20 80
  
  return $?
}

#------------------------------------------------------------------------------
# Select template (interactive or from argument)
#------------------------------------------------------------------------------
function select_template() {
  local param_name="$1"
  
  if [ -n "$param_name" ]; then
    # Direct selection by directory name
    TEMPLATE_NAME="$param_name"
    
    if [ ! -d "$TEMPLATE_REPO_NAME/templates/$TEMPLATE_NAME" ]; then
      echo "❌ Template '$TEMPLATE_NAME' not found"
      rm -rf "$TEMP_DIR"
      exit 2
    fi
    
    # Find index for display
    for i in "${!TEMPLATE_DIRS[@]}"; do
      if [ "${TEMPLATE_DIRS[$i]}" == "$TEMPLATE_NAME" ]; then
        TEMPLATE_INDEX=$i
        break
      fi
    done
  else
    # Interactive menu selection with confirmation
    while true; do
      local choice
      choice=$(show_template_menu)
      TEMPLATE_INDEX=${MENU_TO_INDEX[$choice]}
      
      # Show details and get confirmation
      if show_template_details $TEMPLATE_INDEX; then
        TEMPLATE_NAME="${TEMPLATE_DIRS[$TEMPLATE_INDEX]}"
        break
      fi
      # If user said no, loop back to menu
    done
  fi
  
  clear
  display_intro
  echo "✅ Selected: ${TEMPLATE_NAMES[$TEMPLATE_INDEX]}"
  
  if [ -n "${TEMPLATE_PURPOSES[$TEMPLATE_INDEX]}" ]; then
    echo ""
    echo "📝 About this template:"
    echo "   ${TEMPLATE_PURPOSES[$TEMPLATE_INDEX]}"
  fi
  echo ""
  
  TEMPLATE_PATH="$TEMPLATE_REPO_NAME/templates/$TEMPLATE_NAME"
}

#------------------------------------------------------------------------------
# Verify template structure
#------------------------------------------------------------------------------
function verify_template() {
  echo "🔍 Verifying template structure..."

  if [ ! -d "$TEMPLATE_PATH/manifests" ]; then
    echo "❌ Required directory 'manifests' not found"
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  if [ ! -f "$TEMPLATE_PATH/manifests/deployment.yaml" ]; then
    echo "❌ Required file 'manifests/deployment.yaml' not found"
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  echo "✅ Template structure verified"
  echo ""
}

#------------------------------------------------------------------------------
# Copy template files
#------------------------------------------------------------------------------
function copy_template_files() {
  echo "📦 Extracting template files..."
  cp -r "$TEMPLATE_PATH/"* "$OLDPWD/"

  if [ -d "$TEMPLATE_REPO_NAME/urbalurba-scripts" ]; then
    echo "   Setting up urbalurba-scripts..."
    mkdir -p "$OLDPWD/urbalurba-scripts"
    cp -r "$TEMPLATE_REPO_NAME/urbalurba-scripts/"* "$OLDPWD/urbalurba-scripts/"
    chmod +x "$OLDPWD/urbalurba-scripts/"*.sh 2>/dev/null || true
    echo "   ✅ Added urbalurba-scripts"
  fi
  
  echo ""
}

#------------------------------------------------------------------------------
# Setup GitHub workflows
#------------------------------------------------------------------------------
function setup_github_workflows() {
  if [ -d "$TEMPLATE_PATH/.github" ]; then
    echo "⚙️  Setting up GitHub workflows..."
    mkdir -p "$OLDPWD/.github/workflows"
    cp -r "$TEMPLATE_PATH/.github"/* "$OLDPWD/.github/"
    echo "   ✅ Added GitHub workflows"
    echo ""
  fi
}

#------------------------------------------------------------------------------
# Merge .gitignore files
#------------------------------------------------------------------------------
function merge_gitignore() {
  if [ -f "$TEMPLATE_PATH/.gitignore" ]; then
    echo "🔀 Merging .gitignore files..."
    
    if [ -f "$OLDPWD/.gitignore" ]; then
      TEMP_MERGED=$(mktemp)
      cat "$OLDPWD/.gitignore" > "$TEMP_MERGED"
      echo "" >> "$TEMP_MERGED"
      echo "# Added from template $TEMPLATE_NAME" >> "$TEMP_MERGED"
      
      while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
          if ! grep -Fxq "$line" "$OLDPWD/.gitignore"; then
            echo "$line" >> "$TEMP_MERGED"
          fi
        fi
      done < "$TEMPLATE_PATH/.gitignore"
      
      if cat "$TEMP_MERGED" > "$OLDPWD/.gitignore"; then
        echo "   ✅ Merged .gitignore files"
        rm -f "$TEMP_MERGED"
      else
        echo "   ❌ Failed to merge .gitignore"
        rm -f "$TEMP_MERGED"
        exit 1
      fi
    else
      cp "$TEMPLATE_PATH/.gitignore" "$OLDPWD/"
      echo "   ✅ Copied .gitignore"
    fi
    echo ""
  fi
}

#------------------------------------------------------------------------------
# Replace template variables in file
#------------------------------------------------------------------------------
function replace_placeholders() {
  local file=$1
  local temp_file=$(mktemp)
  
  if [ -f "$file" ]; then
    cat "$file" | \
      sed -e "s|{{GITHUB_USERNAME}}|$GITHUB_USERNAME|g" \
          -e "s|{{REPO_NAME}}|$REPO_NAME|g" > "$temp_file"
    
    if cat "$temp_file" > "$file"; then
      echo "      ✅ $(basename "$file")"
    else
      echo "      ❌ $(basename "$file")"
      return 1
    fi
    rm "$temp_file"
  fi
  
  return 0
}

#------------------------------------------------------------------------------
# Process template variables
#------------------------------------------------------------------------------
function process_essential_files() {
  echo "⚙️  Processing template variables..."
  
  if [ -d "manifests" ]; then
    echo "   📄 Updating manifest files:"
    for manifest_file in manifests/*.yaml manifests/*.yml; do
      if [ -f "$manifest_file" ]; then
        replace_placeholders "$manifest_file"
      fi
    done
  fi
  
  if [ -d ".github/workflows" ]; then
    echo "   📄 Updating workflow files:"
    for workflow_file in .github/workflows/*.yaml .github/workflows/*.yml; do
      if [ -f "$workflow_file" ]; then
        replace_placeholders "$workflow_file"
      fi
    done
  fi
  
  echo ""
}

#------------------------------------------------------------------------------
# Cleanup and show completion
#------------------------------------------------------------------------------
function cleanup_and_complete() {
  echo "🧹 Cleaning up..."
  echo "   Removing: $TEMP_DIR"
  rm -rf "$TEMP_DIR"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Template setup complete!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📝 Next steps:"
  echo "   1. Review the files that were created"
  echo "   2. Run any setup commands in the template's README"
  echo "   3. Commit and push your project to GitHub"
  echo ""
}

#------------------------------------------------------------------------------
# Main execution
#------------------------------------------------------------------------------

# Get template name from command line (optional)
TEMPLATE_NAME="${1:-}"

# Check for dialog
check_dialog

# Show intro
clear
display_intro

# Run the process
detect_github_info
clone_template_repo
scan_templates
select_template "$TEMPLATE_NAME"
verify_template
copy_template_files
setup_github_workflows
merge_gitignore

# Go back to original directory
cd "$OLDPWD"

# Process files
process_essential_files

cleanup_and_complete
