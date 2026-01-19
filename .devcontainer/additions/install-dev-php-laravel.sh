#!/bin/bash
# file: .devcontainer/additions/install-dev-php-laravel.sh
#
# For usage information, run: ./install-dev-php-laravel.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-php-laravel"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="PHP Laravel Development Tools"
SCRIPT_DESCRIPTION="Installs PHP 8.4, Composer, Laravel installer, and sets up Laravel development environment"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="([ -f /usr/bin/php ] || command -v php >/dev/null 2>&1) && ([ -f /usr/local/bin/composer ] || command -v composer >/dev/null 2>&1) && ([ -f $HOME/.composer/vendor/bin/laravel ] || command -v laravel >/dev/null 2>&1)"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="php laravel composer artisan blade web framework"
SCRIPT_ABSTRACT="PHP Laravel development environment with PHP 8.4, Composer, Laravel installer, and VS Code extensions."
SCRIPT_LOGO="dev-php-laravel-logo.webp"
SCRIPT_WEBSITE="https://laravel.com"
SCRIPT_SUMMARY="Complete PHP Laravel development setup including PHP 8.4, Composer package manager, Laravel installer, and comprehensive VS Code extensions for Intelephense, Xdebug, Blade templates, Artisan commands, and namespace resolution."
SCRIPT_RELATED="dev-typescript dev-python"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install PHP Laravel development tools||false|"
    "Action|--uninstall|Uninstall PHP Laravel development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# --- Default Configuration ---
DEFAULT_VERSION="8.4"
TARGET_VERSION=""

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Node.js packages (Node.js already in base devcontainer - see Dockerfile.base)
PACKAGES_NODE=()

# Python packages (not needed for Laravel development)
PACKAGES_PYTHON=()

# PowerShell modules (not needed for Laravel development)
PACKAGES_PWSH=()

# VS Code extensions (PHP/Laravel-specific only)
# Note: For database management and API testing, install: install-tool-dev-utils.sh
EXTENSIONS=(
    "PHP Intelephense (bmewburn.vscode-intelephense-client) - Advanced PHP language support with IntelliSense"
    "PHP Debug (xdebug.php-debug) - Debug PHP applications using Xdebug"
    "PHP DocBlocker (neilbrayfield.php-docblocker) - Automatically generate PHPDoc comments"
    "Composer (ikappas.composer) - Composer dependency manager integration"
    "PHP Namespace Resolver (mehedidracula.php-namespace-resolver) - Auto-import and resolve PHP namespaces"
    "Laravel Blade Snippets (onecentlin.laravel-blade) - Blade syntax highlighting and snippets"
    "Laravel Artisan (ryannaddy.laravel-artisan) - Run Laravel Artisan commands from VS Code"
)

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
        echo "⚠️  Note: PHP installed via Herd-lite may require manual removal"
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if PHP is already installed
        if command -v php >/dev/null 2>&1; then
            echo "✅ PHP is already installed (version: $(php --version | head -n 1))"

            if command -v composer >/dev/null 2>&1; then
                echo "✅ Composer is already installed (version: $(composer --version | head -n 1))"
            fi

            if command -v laravel >/dev/null 2>&1; then
                echo "✅ Laravel installer is already installed (version: $(laravel --version))"
            fi
        else
            # Determine version to install
            local version="${TARGET_VERSION:-$DEFAULT_VERSION}"
            echo "📦 Installing PHP ${version}, Composer, and Laravel installer..."

            # Install PHP stack using Laravel's official Herd-lite installer
            if ! /bin/bash -c "$(curl -fsSL https://php.new/install/linux/${version})"; then
                echo "❌ Failed to install PHP stack"
                exit 1
            fi

            # Source bashrc to update PATH for current session
            if [ -f "$HOME/.bashrc" ]; then
                echo "🔄 Updating PATH for current session..."
                # shellcheck source=/dev/null
                source "$HOME/.bashrc"

                # Also update PATH for this script execution
                export PATH="$HOME/.config/herd-lite/bin:$PATH"
            fi

            echo "✅ PHP stack installation completed"
        fi

        # Detect if we're in a Laravel project and set up project dependencies
        detect_and_setup_laravel_project

        if [ -f "$HOME/.bashrc" ]; then
            echo "🔄 PATH has been configured in ~/.bashrc for future terminal sessions"
        fi
    fi
}

# --- Check and Fix Vite Configuration ---
check_and_fix_vite_config() {
    local vite_config="vite.config.js"

    if [[ ! -f "$vite_config" ]]; then
        echo "⚠️  No vite.config.js found - skipping Vite configuration check"
        return 0
    fi

    # Check if the config already has devcontainer-friendly settings
    if grep -q "host: '0.0.0.0'" "$vite_config" || grep -q 'host: "0.0.0.0"' "$vite_config"; then
        echo "✅ Vite configuration already compatible with devcontainers"
        return 0
    fi

    echo "🔍 Checking Vite configuration for devcontainer compatibility..."
    echo "   Current config binds to localhost only, which may cause asset loading issues"
    echo "   in devcontainer environments."
    echo ""
    echo "   Recommended fix: Update vite.config.js to bind to all interfaces (0.0.0.0)"
    echo "   This is safe for development and required for devcontainers."
    echo ""

    # In uninstall mode, don't prompt
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return 0
    fi

    # Prompt for permission to update
    read -p "Would you like to update vite.config.js for devcontainer compatibility? (y/N): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⚠️  Vite config not updated. You may experience asset loading issues."
        echo "   If you encounter problems, manually add this to your vite.config.js:"
        echo "   server: { host: '0.0.0.0', port: 5173, hmr: { host: 'localhost' } }"
        return 0
    fi

    # Backup the original file
    cp "$vite_config" "${vite_config}.backup"
    echo "📄 Created backup: ${vite_config}.backup"

    # Create the updated config
    cat > "$vite_config" << 'EOF'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    server: {
        host: '0.0.0.0',
        port: 5173,
        hmr: {
            host: 'localhost'
        }
    },
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
});
EOF

    echo "✅ Updated vite.config.js for devcontainer compatibility"
    echo "   - Server now binds to 0.0.0.0 (required for containers)"
    echo "   - HMR configured for localhost (for browser hot reload)"
    echo "   - Original config backed up as ${vite_config}.backup"
}

# --- Detect and Setup Laravel Project ---
detect_and_setup_laravel_project() {
    # Check if we're in a Laravel project directory
    if [[ -f "composer.json" && -f "artisan" ]]; then
        echo "🎯 Laravel project detected - setting up project dependencies..."

        # Install Composer dependencies if vendor directory doesn't exist or is incomplete
        if [[ ! -d "vendor" || ! -f "vendor/autoload.php" ]]; then
            echo "📦 Installing Composer dependencies..."
            if ! composer install --no-interaction --prefer-dist --optimize-autoloader; then
                echo "❌ Failed to install Composer dependencies"
                return 1
            fi
        else
            echo "✅ Composer dependencies already installed"
        fi

        # Install npm dependencies if package.json exists and node_modules is missing/incomplete
        if [[ -f "package.json" ]]; then
            if [[ ! -d "node_modules" || ! -f "package-lock.json" ]]; then
                echo "📦 Installing npm dependencies..."
                if ! npm install; then
                    echo "❌ Failed to install npm dependencies"
                    return 1
                fi
            else
                echo "✅ npm dependencies already installed"
            fi
        fi

        # Set up Laravel environment file if it doesn't exist
        if [[ -f ".env.example" && ! -f ".env" ]]; then
            echo "🔧 Creating .env file from .env.example..."
            cp .env.example .env

            # Generate app key if it's empty in the .env file
            if ! grep -q "APP_KEY=.*[^=]" .env; then
                echo "🔑 Generating Laravel application key..."
                php artisan key:generate --ansi
            fi
        elif [[ -f ".env" ]]; then
            echo "✅ .env file already exists"

            # Check if app key is set, generate if missing
            if ! grep -q "APP_KEY=.*[^=]" .env; then
                echo "🔑 Generating missing Laravel application key..."
                php artisan key:generate --ansi
            fi
        fi

        # Create SQLite database file if configured and doesn't exist
        if grep -q "DB_CONNECTION=sqlite" .env 2>/dev/null; then
            local db_path="database/database.sqlite"
            if [[ ! -f "$db_path" ]]; then
                echo "🗄️ Creating SQLite database file..."
                touch "$db_path"
            else
                echo "✅ SQLite database file already exists"
            fi

            # Run migrations if the database is empty (check for users table)
            if ! php artisan migrate:status 2>/dev/null | grep -q "users"; then
                echo "🗄️ Running database migrations..."
                if ! php artisan migrate --force --no-interaction; then
                    echo "⚠️  Warning: Database migrations failed - you may need to run them manually"
                fi
            else
                echo "✅ Database migrations already applied"
            fi
        fi

        # Check and fix Vite configuration for devcontainer compatibility
        check_and_fix_vite_config

        echo "✅ Laravel project setup completed"
    else
        echo "📁 No Laravel project detected in current directory"
        echo "   After installation, you can create a new Laravel project with:"
        echo "   laravel new my-project"
        echo "   or: composer create-project laravel/laravel my-project"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local php_version
    local composer_version
    local laravel_version

    php_version=$(php --version 2>/dev/null | head -n 1 || echo "not found")
    composer_version=$(composer --version 2>/dev/null | head -n 1 || echo "not found")
    laravel_version=$(laravel --version 2>/dev/null || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   PHP: $php_version"
    echo "   Composer: $composer_version"
    echo "   Laravel: $laravel_version"
    echo
    echo "Quick start commands:"
    echo "  - Create new project:    laravel new my-project"
    echo "  - Alternative:           composer create-project laravel/laravel my-project"
    echo "  - Start dev server:      composer run dev"
    echo "  - Run individual server: php artisan serve"
    echo "  - Laravel REPL:          php artisan tinker"
    echo "  - Run migrations:        php artisan migrate"
    echo "  - Run tests:             composer run test"
    echo
    echo "Development workflow:"
    echo "  1. Run: composer run dev (starts Laravel + Vite + Queue + Logs)"
    echo "  2. Open: http://localhost:8000"
    echo "  3. Edit files - Vite auto-reloads CSS/JS changes"
    echo
    echo "Note: For devcontainer compatibility:"
    echo "  - Laravel server: port 8000 (main application)"
    echo "  - Vite server: port 5173 (assets only)"
    echo "  - Use port 8000 in browser (Vite runs in background)"
    echo
    echo "Optional: Install database and API testing tools:"
    echo "  .devcontainer/additions/install-tool-dev-utils.sh"
    echo "  (Installs SQLTools for databases and REST Client for API testing)"
    echo
    echo "Docs: https://laravel.com/docs/12.x"
    echo

    # Show Laravel project status if detected
    if [[ -f "composer.json" && -f "artisan" ]]; then
        echo "Laravel Project Status:"
        [[ -f ".env" ]] && echo "✅ Environment configured" || echo "⚠️  Run: cp .env.example .env && php artisan key:generate"
        [[ -d "vendor" ]] && echo "✅ Composer dependencies installed" || echo "⚠️  Run: composer install"
        [[ -f "database/database.sqlite" ]] && echo "✅ SQLite database exists" || echo "⚠️  Run: touch database/database.sqlite"
        echo
    fi

    echo "Next steps:"
    echo "  1. Run: source ~/.bashrc"
    echo "  2. Then: composer run dev"
    echo "  3. Open: http://localhost:8000"
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ VS Code extensions removed"
    echo
    echo "Note: PHP installed via Herd-lite remains in ~/.config/herd-lite/"
    echo "To completely remove:"
    echo "  rm -rf ~/.config/herd-lite"
    echo "  # Then edit ~/.bashrc to remove PATH entry"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Use standard processing from lib/install-common.sh
    process_standard_installations
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    show_install_header "uninstall"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    show_install_header
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
