# filename: containers/postgresql/Dockerfile
#
# Multi-stage Dockerfile for building Urbalurba PostgreSQL with Extensions
#
# This Dockerfile extends the official Bitnami PostgreSQL 16 image with additional
# extensions required for modern AI and data-intensive applications. It uses a 
# multi-stage build approach to efficiently copy pgvector from the official
# pgvector image while installing other extensions via package manager.
#
# Base Image: bitnami/postgresql:16
# Extensions Added:
#   - pgvector: Vector similarity search and AI embeddings
#   - PostGIS: Geospatial data types and operations  
#   - hstore: Key-value pairs in database columns
#   - ltree: Hierarchical tree-like data structures
#   - uuid-ossp: UUID generation functions
#   - pg_trgm: Trigram matching for fuzzy text search
#   - btree_gin: Additional indexing methods
#   - pgcrypto: Cryptographic functions
#
# Security Model: Maintains Bitnami's non-root approach (UID 1001)
# Architectures: linux/amd64, linux/arm64

# ==============================================================================
# STAGE 1: PGVECTOR SOURCE
# Extract pgvector extension files from the official pgvector image
# This approach ensures we get the latest stable pgvector build
# ==============================================================================
FROM pgvector/pgvector:pg16 AS pgvector_source

# Note: This stage only serves as a source for copying files
# We use the official pgvector image to ensure compatibility and security

# ==============================================================================
# STAGE 2: MAIN BUILD
# Build the final PostgreSQL image with all extensions
# ==============================================================================
FROM bitnami/postgresql:16

# ------------------------------------------------------------------------------
# IMAGE METADATA
# Standard OCI labels for better container identification and documentation
# ------------------------------------------------------------------------------
LABEL org.opencontainers.image.title="Urbalurba PostgreSQL"
LABEL org.opencontainers.image.description="PostgreSQL with pgvector, PostGIS, hstore, and ltree for Urbalurba Infrastructure"
LABEL org.opencontainers.image.vendor="Urbalurba Infrastructure"
LABEL org.opencontainers.image.source="https://github.com/terchris/urbalurba-infrastructure"
LABEL org.opencontainers.image.documentation="https://github.com/terchris/urbalurba-infrastructure/blob/main/containers/postgresql/readme-postgres-container.md"

# ------------------------------------------------------------------------------
# SYSTEM PACKAGE INSTALLATION
# Switch to root temporarily to install system packages
# Bitnami images use non-root by default, so we need root for apt operations
# ------------------------------------------------------------------------------
USER root

# Install PostgreSQL extensions and dependencies via apt
# We use --no-install-recommends to minimize image size
# Add PostgreSQL official repository for latest packages
RUN apt-get update && \
    # Install dependencies for adding repositories
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
    # Add PostgreSQL official APT repository (PGDG)
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    # Update package list with new repository
    && apt-get update \
    # Install PostgreSQL extensions
    && apt-get install -y --no-install-recommends \
        # PostGIS: Geospatial extension with supporting scripts
        postgresql-16-postgis-3 \
        postgresql-16-postgis-3-scripts \
        # PostgreSQL contrib: Additional community extensions
        # Includes: hstore, ltree, uuid-ossp, pg_trgm, btree_gin, pgcrypto
        postgresql-contrib-16 \
    # Clean up package manager cache to reduce image size
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ------------------------------------------------------------------------------
# PGVECTOR INSTALLATION
# Copy pgvector extension files from the source stage
# This approach ensures we get the exact same pgvector build as the official image
# ------------------------------------------------------------------------------

# Copy the compiled pgvector shared library
# This contains the actual pgvector functionality
COPY --from=pgvector_source \
    /usr/lib/postgresql/16/lib/vector.so \
    /opt/bitnami/postgresql/lib/

# Copy pgvector extension control and SQL files
# These define the extension interface and installation scripts
# The wildcard pattern captures all version-specific SQL files
COPY --from=pgvector_source \
    /usr/share/postgresql/16/extension/vector.control \
    /usr/share/postgresql/16/extension/vector--*.sql \
    /opt/bitnami/postgresql/share/extension/

# ------------------------------------------------------------------------------
# FILE OWNERSHIP AND PERMISSIONS
# Ensure proper ownership for Bitnami's non-root security model
# Bitnami containers run as UID 1001 for security
# ------------------------------------------------------------------------------

# Set ownership of pgvector files to the Bitnami user (1001:1001)
# This is critical for the non-root security model to work correctly
RUN chown -R 1001:1001 /opt/bitnami/postgresql/lib/vector.so && \
    chown -R 1001:1001 /opt/bitnami/postgresql/share/extension/vector*

# ------------------------------------------------------------------------------
# EXTENSION VERIFICATION SCRIPT
# Create a script to verify all extension files are properly installed
# This helps with debugging and ensures container integrity
# ------------------------------------------------------------------------------

# Create verification script using heredoc syntax for clean inline scripting
# This script checks that all required extension files are present
COPY <<EOF /opt/bitnami/scripts/postgresql/verify-extensions.sh
#!/bin/bash
set -e

echo "🔍 Verifying PostgreSQL extensions are available..."

# Check pgvector library file exists
if [ -f "/opt/bitnami/postgresql/lib/vector.so" ]; then
    echo "✅ pgvector library found"
else
    echo "❌ pgvector library missing"
    exit 1
fi

# Check pgvector control file exists
if [ -f "/opt/bitnami/postgresql/share/extension/vector.control" ]; then
    echo "✅ pgvector control file found"
else
    echo "❌ pgvector control file missing"
    exit 1
fi

# Check PostGIS library (installed via apt package)
if [ -f "/usr/lib/postgresql/16/lib/postgis-3.so" ]; then
    echo "✅ PostGIS library found"
else
    echo "❌ PostGIS library missing"
    exit 1
fi

echo "🎉 All extension files verified successfully!"
EOF

# Make the verification script executable
RUN chmod +x /opt/bitnami/scripts/postgresql/verify-extensions.sh

# ------------------------------------------------------------------------------
# SECURITY: RETURN TO NON-ROOT USER
# Switch back to Bitnami's non-root user for security
# This is critical for production security compliance
# ------------------------------------------------------------------------------
USER 1001

# ------------------------------------------------------------------------------
# BUILD-TIME VERIFICATION
# Run the verification script during build to catch issues early
# This ensures the container build fails if extensions are missing
# ------------------------------------------------------------------------------
RUN /opt/bitnami/scripts/postgresql/verify-extensions.sh

# ------------------------------------------------------------------------------
# HEALTH CHECK
# Note: Bitnami PostgreSQL images already include a comprehensive health check
# We don't need to add our own as it would override Bitnami's optimized version
# The existing health check monitors PostgreSQL readiness and availability
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CONTAINER RUNTIME
# Use the original Bitnami entrypoint and command
# This maintains all Bitnami functionality (initialization, configuration, etc.)
# while adding our extensions
# 
# Note: We don't need to specify CMD/ENTRYPOINT as we inherit from the base image
# Bitnami's entrypoint handles:
#   - Database initialization
#   - Configuration file generation
#   - User/database creation
#   - Extension loading
#   - PostgreSQL startup
# ------------------------------------------------------------------------------

# The container will start PostgreSQL with all extensions available
# Extensions can be enabled per-database using: CREATE EXTENSION IF NOT EXISTS extension_name;
