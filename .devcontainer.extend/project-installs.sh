#!/bin/bash
# File: .devcontainer.extend/project-installs.sh
# Purpose: Project-specific custom installations
# Called by: .devcontainer/manage/postCreateCommand.sh (after standard tools are installed)
#
# DEVELOPERS: Add your project-specific installation logic here.
# This script runs AFTER all standard tools from enabled-tools.conf are installed.
#
# Use this for:
#   - Project-specific npm/pip/cargo packages
#   - Database setup scripts
#   - API client generation
#   - Custom configuration
#   - Any project-specific setup that isn't covered by standard tools

set -e

# Force carriage return before starting (in case terminal state is corrupted)
printf "\r\n"
printf "🔧 Running custom project-specific installations...\r\n"
printf "\r\n"

#------------------------------------------------------------------------------
# ADD YOUR CUSTOM INSTALLATIONS BELOW
#------------------------------------------------------------------------------

# Example: Installing Azure Functions Core Tools
# echo "Installing Azure Functions Core Tools..."
# npm install -g azure-functions-core-tools@4

# Example: Installing specific Python packages
# echo "Installing Python packages..."
# pip install pandas numpy matplotlib

# Example: Installing project dependencies
# echo "Installing project dependencies..."
# cd /workspace
# npm install

# Example: Running database setup
# echo "Setting up database..."
# bash /workspace/scripts/db-setup.sh

# Example: Generating API clients
# echo "Generating API clients..."
# bash /workspace/scripts/generate-client.sh

#------------------------------------------------------------------------------
# END CUSTOM INSTALLATIONS
#------------------------------------------------------------------------------

printf "✅ Custom project installations complete\r\n"
printf "\r\n"

exit 0
