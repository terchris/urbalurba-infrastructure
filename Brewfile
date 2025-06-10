# Brewfile for Urbalurba Infrastructure
# Location: https://github.com/terchris/urbalurba-infrastructure/main/Brewfile
#
# Urbalurba Infrastructure is a local development environment that provides
# the services of a modern datacenter, enabling you to develop software that
# uses state-of-the-art cloud-native systems without having to worry about
# setting up Kubernetes, PostgreSQL, machine learning frameworks, Redis, and more.
#
# See: https://github.com/terchris/urbalurba-infrastructure
#
# Prerequisites:
# 1. Install Homebrew first: https://brew.sh/
# 2. Run this Brewfile: brew bundle --file=Brewfile
#
# This Brewfile installs the minimum software needed on a new Mac for
# cloud-native development with Urbalurba Infrastructure.

# ===== HOMEBREW SETUP =====
tap "homebrew/bundle"
tap "homebrew/cask"

# ===== CORE INFRASTRUCTURE =====

# Rancher Desktop - Kubernetes + Docker for local development
# Provides complete container and Kubernetes environment on macOS
# Includes kubectl, helm, and Docker automatically
cask "rancher"

# k9s - Terminal-based Kubernetes UI
# Provides interactive cluster management and monitoring
brew "k9s"

# ===== INSTALLATION NOTES =====
#
# After running this Brewfile:
#
# 1. Configure Rancher Desktop:
#    - Open Rancher Desktop from Applications
#    - Set Memory: 8GB, CPUs: 4 cores
#    - Enable VZ virtualization (if available)
#    - Disable auto-start to save resources
#
# 2. Verify installation:
#    - kubectl version (included with Rancher Desktop)
#    - docker version (included with Rancher Desktop)
#    - k9s (terminal Kubernetes manager)
#
# Rancher Desktop includes kubectl, helm, and Docker automatically,
# so you get a complete Kubernetes development environment with just these two installs.
#
# For more details, see the Urbalurba Infrastructure documentation:
# https://github.com/terchris/urbalurba-infrastructure
