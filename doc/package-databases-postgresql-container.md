# PostgreSQL Container for Urbalurba Infrastructure

**File**: `doc/package-postgresql-container.md`
**Purpose**: Complete documentation for custom PostgreSQL container with AI/ML extensions and CI/CD automation
**Target Audience**: Infrastructure engineers, DevOps teams, and developers working with PostgreSQL extensions
**Last Updated**: September 22, 2024

## 📋 Overview

This document covers the custom PostgreSQL container (`containers/postgresql/`) that extends the official Bitnami PostgreSQL image with additional extensions required for the Urbalurba platform. This custom container provides enhanced functionality for modern applications requiring vector search, geospatial data, and hierarchical data structures.

The container is automatically built and published via **GitHub Actions CI/CD** to GitHub Container Registry with full multi-architecture support.

## Why Custom Container?

The standard Bitnami PostgreSQL image doesn't include certain extensions that are crucial for modern AI and data-intensive applications:

- **pgvector**: Essential for vector search and AI embeddings
- **PostGIS**: Required for geospatial data types and queries
- **hstore**: Enables key-value storage within PostgreSQL columns
- **ltree**: Supports hierarchical/tree-like data structures

## Extensions Included

| Extension | Version | Purpose |
|-----------|---------|---------|
| **pgvector** | Latest | Vector similarity search and AI embeddings |
| **PostGIS** | 3.x | Geospatial data types, functions, and indexing |
| **hstore** | Built-in | Key-value pairs in single values |
| **ltree** | Built-in | Hierarchical tree-like data |
| **uuid-ossp** | Built-in | UUID generation functions |
| **pg_trgm** | Built-in | Trigram matching for fuzzy text search |
| **btree_gin** | Built-in | Additional indexing methods |
| **pgcrypto** | Built-in | Cryptographic functions |

## Container Details

- **Base Image**: `bitnami/postgresql:16`
- **Registry**: `ghcr.io/terchris/urbalurba-postgresql`
- **Architectures**: `linux/amd64`, `linux/arm64`
- **Security**: Runs as non-root user (UID 1001)
- **Optimization**: Multi-stage build for minimal size
- **Package Source**: PostgreSQL official repository (PGDG) for latest packages
- **Build Dependencies**: wget, ca-certificates, gnupg, lsb-release (cleaned up after build)

## Development Workflow

### Optimal Multi-Architecture Development

Take advantage of your local hardware for comprehensive testing:

```bash
# 1. Local Development & Testing (Your Mac = Native ARM64)
cd containers/postgresql
./build.sh --single-arch
# ✅ Native ARM64 build and testing
# ✅ All 8 extensions validated
# ✅ Performance testing without emulation

# 2. Commit and Push Changes
git add .
git commit -m "PostgreSQL container improvements"
git push

# 3. CI/CD Automatically Handles:
# ✅ AMD64: Full functional testing (GitHub Actions)
# ✅ ARM64: Build verification (GitHub Actions)
# ✅ Multi-arch: Registry publishing (GitHub Actions)
# ✅ Security: Vulnerability scanning (GitHub Actions)

# 4. Result: Both architectures fully validated!
```

### Why This Works Perfectly

- **Your Mac**: Native ARM64 testing (real performance, all features)
- **GitHub Actions**: Native AMD64 testing (most common deployment)
- **Combined**: Complete multi-architecture confidence
- **No Emulation**: Fast, reliable, production-representative testing

## Local Development

### Prerequisites
- Docker Desktop with BuildKit enabled
- For multi-arch builds: `docker buildx create --use`
- Internet access for PGDG repository during build
- Sufficient disk space for multi-stage build (PostgreSQL 16 + pgvector images)

### Build Locally
```bash
cd containers/postgresql

# Build single architecture (recommended for local testing)
./build.sh --single-arch

# On Apple Silicon Macs: This builds and tests ARM64 natively!
# On Intel/AMD64: This builds and tests AMD64 natively!

# Build multi-architecture (requires push to registry)
./build.sh --push

# Build specific version
./build.sh --version v1.2.0 --push

# Show all options
./build.sh --help
```

### Build Options
- `--single-arch`: Build for current architecture only (faster, good for local testing)
- `--push`: Push to registry (required for multi-arch builds)
- `--version VERSION`: Set custom version tag
- `--platform PLATFORMS`: Set target platforms (default: linux/amd64,linux/arm64)
- `--help`: Show detailed usage information

### Test Locally
```bash
# Run the container
docker run -d --name postgres-test \
  -e POSTGRESQL_PASSWORD=testpass123 \
  -e POSTGRESQL_POSTGRES_PASSWORD=testpass123 \
  -e POSTGRESQL_DATABASE=testdb \
  -p 5432:5432 \
  ghcr.io/terchris/urbalurba-postgresql:latest

# Wait for PostgreSQL to be ready
docker exec postgres-test pg_isready -U postgres

# Test all extensions (with authentication)
docker exec -e PGPASSWORD=testpass123 postgres-test psql -U postgres -d testdb -c "
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS hstore;
  CREATE EXTENSION IF NOT EXISTS ltree;
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS btree_gin;
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
"

# Verify extensions are installed
docker exec -e PGPASSWORD=testpass123 postgres-test psql -U postgres -d testdb -c \
  "SELECT extname FROM pg_extension WHERE extname NOT IN ('plpgsql') ORDER BY extname;"

# Cleanup
docker stop postgres-test && docker rm postgres-test
```

### Automated Testing
The build script includes comprehensive automated testing:
- Verifies all 8 extensions install correctly
- Tests basic functionality of each extension
- Validates vector operations, geospatial queries, and hierarchical data
- Automatically cleans up test containers

## Integration with Urbalurba Infrastructure

### In Kubernetes Manifests
Update your `manifests/042-database-postgresql-config.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: postgresql
        image: ghcr.io/terchris/urbalurba-postgresql:latest
```

### In Ansible Playbooks
Reference in `ansible/playbooks/040-database-postgresql.yml`:

```yaml
- name: Deploy custom PostgreSQL
  kubernetes.core.k8s:
    definition:
      spec:
        template:
          spec:
            containers:
            - image: ghcr.io/terchris/urbalurba-postgresql:latest
```

## 🔄 CI/CD Pipeline with GitHub Actions

The container is automatically built and published via **GitHub Actions** using the workflow at `.github/workflows/build-postgresql-container.yml`. This provides comprehensive automation for building, testing, and publishing the PostgreSQL container.

### **Workflow Overview**

**File**: `.github/workflows/build-postgresql-container.yml`
**Purpose**: Automated multi-architecture container builds with security scanning and testing

### **Workflow Triggers**

The workflow runs automatically on:
- **Push to main** - When PostgreSQL container files change (`containers/postgresql/**`)
- **Pull requests** - For testing changes before merge
- **Release tags** - For versioned releases
- **Manual dispatch** - With custom version parameters

### **Multi-Job Architecture**

#### **1. Build Job** 🚀
- **Platform**: Ubuntu (GitHub Actions)
- **Duration**: ~15 minutes
- **Architectures**: `linux/amd64`, `linux/arm64`
- **Registry**: GitHub Container Registry (`ghcr.io`)

**Key Features**:
- Multi-architecture builds using Docker Buildx
- Automatic tagging based on trigger type
- BuildKit caching for faster subsequent builds
- Metadata generation with OCI labels

**Generated Tags**:
- `latest` - Main branch pushes
- `v1.0.0` - Release tags
- `pr-123` - Pull request builds
- `main-abc1234-20241201` - SHA-based unique tags

#### **2. Security Scan Job** 🛡️
- **Platform**: Ubuntu (GitHub Actions)
- **Duration**: ~5 minutes
- **Tool**: Trivy vulnerability scanner
- **Scope**: CRITICAL and HIGH severity issues

**Security Features**:
- SARIF report generation for GitHub Security tab
- Human-readable vulnerability summaries
- Automatic upload to GitHub Security dashboard
- Failure tolerance (workflow continues even with vulnerabilities)

#### **3. Test Job** 🧪
- **Platform**: Ubuntu (GitHub Actions)
- **Duration**: ~10 minutes
- **Architecture**: AMD64 (native testing)
- **Extensions Tested**: All 8 extensions validated

**Testing Strategy**:
- **AMD64**: Full functional testing on native GitHub runners
- **PostgreSQL Client**: Uses official PostgreSQL client tools
- **Extension Validation**: Creates and tests all extensions
- **Functional Tests**: Vector operations, geospatial queries, hierarchical data
- **Health Checks**: Built-in container health monitoring

**Why AMD64 Only for Testing**:
- GitHub Actions runners are AMD64-only (no native ARM64)
- QEMU emulation for ARM64 testing is unreliable for complex containers
- ARM64 build verification happens separately (see ARM64 Verification job)

#### **4. ARM64 Verification Job** 🔍
- **Platform**: Ubuntu (GitHub Actions)
- **Duration**: ~3 minutes
- **Purpose**: Verify ARM64 images build and can be pulled

**Verification Process**:
- Manifest inspection for ARM64 variant
- Image pull test for ARM64 architecture
- Basic image metadata validation
- **No emulated runtime testing** (by design for reliability)

### **Workflow Permissions**

```yaml
permissions:
  contents: read          # Read repository contents
  packages: write         # Push to GitHub Container Registry
  security-events: write  # Upload security scan results
```

### **Environment Variables**

```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/urbalurba-postgresql
```

### **Manual Workflow Dispatch**

The workflow supports manual triggering with custom parameters:

```bash
# Via GitHub UI or gh CLI:
gh workflow run build-postgresql-container.yml \
  -f version=v1.3.0 \
  -f push_image=true
```

**Parameters**:
- `version`: Custom container version tag
- `push_image`: Whether to push to registry (default: true)

### **Workflow Outputs**

Each workflow run generates:
- **Build artifacts**: Multi-architecture container images
- **Security reports**: Vulnerability scan results in GitHub Security tab
- **Test results**: Extension functionality validation
- **Workflow summary**: Human-readable results with tags, digests, and test status

### **Registry Integration**

- **Registry**: GitHub Container Registry (`ghcr.io`)
- **Authentication**: Automatic via `GITHUB_TOKEN`
- **Visibility**: Public (linked to repository)
- **Retention**: Follows GitHub's container retention policies

### **CI/CD Best Practices Implemented**

1. **Security First**:
   - No secrets in code or logs
   - Vulnerability scanning on every build
   - Read-only permissions where possible

2. **Multi-Architecture Support**:
   - Native AMD64 testing for reliability
   - ARM64 build verification for compatibility
   - Manifest inspection for architecture validation

3. **Caching Strategy**:
   - GitHub Actions cache for Docker builds
   - Layer caching for faster subsequent builds
   - Maximum cache mode for optimal performance

4. **Error Handling**:
   - Retry logic for container startup
   - Comprehensive debugging output
   - Graceful failure handling

5. **Observability**:
   - Detailed workflow summaries
   - Test result reporting
   - Build artifact tracking

## Image Tags

- `ghcr.io/terchris/urbalurba-postgresql:latest` - Latest stable build
- `ghcr.io/terchris/urbalurba-postgresql:v1.0.0` - Specific version
- `ghcr.io/terchris/urbalurba-postgresql:pr-123` - Pull request builds

## Multi-Architecture Support

### CI/CD Testing Strategy
Our testing approach balances reliability with multi-architecture support:

**AMD64 Testing (Full)**:
- ✅ Native testing on GitHub Actions runners
- ✅ Complete functional tests with all 8 extensions
- ✅ Performance validation and integration testing

**ARM64 Verification (Build-Only)**:
- ✅ Multi-architecture build verification
- ✅ Image availability and pull testing
- ✅ Manifest inspection and architecture validation
- ⚠️ **No emulated runtime testing** (avoided due to QEMU reliability issues)

### Why This Approach?

**GitHub Actions Limitation**: Standard GitHub-hosted runners are AMD64-only. ARM64 container testing requires QEMU emulation, which:
- Is significantly slower (5-10x overhead)
- Has reliability issues with complex containers
- Can produce false failures due to timing/emulation problems
- Doesn't represent real ARM64 performance

**Production Confidence**: 
- AMD64 gets full testing (most common deployment target)
- ARM64 build process is verified (image exists and is pullable)
- Multi-architecture manifest is validated
- Production ARM64 deployments can be validated separately

### ARM64 Testing (Apple Silicon Mac)

If you're on Apple Silicon (M1/M2/M3), you can test ARM64 natively:

```bash
# Native ARM64 testing on Apple Silicon
./build.sh --single-arch

# This provides:
# ✅ Native ARM64 performance (no emulation)
# ✅ Complete functional testing
# ✅ All 8 extensions validated
# ✅ Real-world ARM64 confidence
```

### ARM64 Production Validation

For ARM64 production deployments, validate manually:

```bash
# On ARM64 hardware (Apple Silicon, AWS Graviton, etc.)
docker run --rm \
  -e POSTGRESQL_PASSWORD=testpass \
  -e POSTGRESQL_DATABASE=testdb \
  ghcr.io/terchris/urbalurba-postgresql:latest \
  psql -U postgres -d testdb -c "CREATE EXTENSION vector; SELECT version();"
```

## Usage Examples

### Basic PostgreSQL with Extensions
```sql
-- Connect to database
\c your_database

-- Create vector search table
CREATE TABLE documents (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(1536),
  metadata hstore
);

-- Create spatial data table
CREATE TABLE locations (
  id SERIAL PRIMARY KEY,
  name TEXT,
  coordinates GEOMETRY(POINT, 4326)
);

-- Create hierarchical data
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  path ltree
);
```

### Performance Indexes
```sql
-- Vector similarity index
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops);

-- Spatial index
CREATE INDEX ON locations USING gist(coordinates);

-- Hierarchical index
CREATE INDEX ON categories USING gist(path);
```

## Troubleshooting

### Common Issues

1. **Extension not available**: Verify the container is using the custom image
2. **Permission denied**: Extensions require superuser privileges during installation
3. **Build failures**: Check Docker BuildKit is enabled
4. **Package not found errors**: The build now automatically adds PostgreSQL official repository (PGDG)
5. **Architecture testing**: Use `./build.sh --single-arch` on your Mac for native ARM64 testing

### Fixed Issues (v1.2.0+)

**PostgreSQL 16 package availability**: 
- **Problem**: `postgresql-16-postgis-3` and `postgresql-contrib-16` packages not found in Debian repositories
- **Solution**: Automatically adds PostgreSQL official repository (PGDG) during build
- **Impact**: All PostgreSQL 16 packages now available

**Authentication in tests**:
- **Problem**: psql commands failing with "no password supplied" error and container startup failing with "POSTGRESQL_PASSWORD environment variable is empty"
- **Solution**: Added both `POSTGRESQL_PASSWORD` and `POSTGRESQL_POSTGRES_PASSWORD` environment variables, plus `PGPASSWORD` for test commands
- **Impact**: Container startup and automated testing now work reliably

**SQL syntax in extension verification**:
- **Problem**: `ORDER BY` clause error in `string_agg()` queries
- **Solution**: Moved `ORDER BY` inside the aggregate function
- **Impact**: Extension verification queries now work correctly

**Container cleanup conflicts**:
- **Problem**: Test containers with same name causing build failures
- **Solution**: Added pre-test cleanup and robust error handling
- **Impact**: Builds can run repeatedly without manual cleanup

### Debug Commands
```bash
# Check running container
kubectl exec -it postgresql-pod -- psql -U postgres -c "SELECT extname, extversion FROM pg_extension;"

# Verify image
kubectl describe pod postgresql-pod | grep Image:

# Check logs
kubectl logs postgresql-pod

# Local debug - check extension files
docker exec postgres-test ls -la /opt/bitnami/postgresql/lib/vector.so
docker exec postgres-test ls -la /opt/bitnami/postgresql/share/extension/vector*

# Local debug - verify PGDG repository was added
docker exec postgres-test cat /etc/apt/sources.list.d/pgdg.list
```

## Maintenance

### Updating Base Image
1. Update `FROM bitnami/postgresql:16` to newer version in Dockerfile
2. Test locally with `./build.sh`
3. Create pull request
4. GitHub Actions will build and test
5. Merge triggers automatic deployment

### Adding New Extensions
1. Add installation commands to Dockerfile
2. Update this README documentation
3. Test locally
4. Submit pull request

## Security

- Container runs as non-root user (1001:1001)
- Regular vulnerability scanning via Trivy
- Base image updated automatically via dependabot
- No secrets or credentials in container image
- Network isolation through Kubernetes policies
- **PGDG Repository**: Uses official PostgreSQL repository with verified GPG signatures
- **Build dependencies**: Temporary packages (wget, gnupg) removed after build to minimize attack surface

## Performance Considerations

- Optimized for development and medium-scale production
- Default settings suitable for 1-4GB RAM
- For high-performance workloads, tune PostgreSQL configuration via ConfigMaps
- Monitor with your existing monitoring stack

## Support

For issues related to:
- **Container build**: Check GitHub Actions logs
- **Extension functionality**: Refer to upstream documentation
- **Urbalurba integration**: See main infrastructure documentation
- **Performance tuning**: Consult PostgreSQL documentation

## Version History

- **v1.0.0**: Initial release with pgvector, PostGIS, hstore, ltree
- **v1.1.0**: Added btree_gin and pgcrypto extensions
- **v1.2.0**: Major improvements and fixes:
  - Updated to PostgreSQL 16.x base with PGDG repository
  - Fixed package availability issues for PostgreSQL 16
  - Enhanced build script with comprehensive testing
  - Fixed authentication issues in automated tests
  - Added robust container cleanup and error handling
  - Improved CI/CD pipeline with realistic multi-architecture testing
  - Optimized testing strategy: Native AMD64 (CI) + Native ARM64 (local Mac)
  - Added detailed troubleshooting documentation
  - Eliminated unreliable emulated testing for faster, more reliable builds
