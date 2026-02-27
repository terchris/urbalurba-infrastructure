# Authentik Blueprints Manual

## Overview

Authentik blueprints provide a way to template, automate, and distribute authentik configuration as code. They allow you to define your authentication infrastructure declaratively using YAML files, enabling version control, reproducible deployments, and automated configuration management.

This manual focuses on the **Kubernetes ConfigMap pattern** for blueprint deployment, which provides automatic discovery and application of blueprints when authentik starts.

## Table of Contents

1. [Basic Structure](#basic-structure)
2. [Deployment Patterns](#deployment-patterns)
3. [Helm Configuration for Blueprints](#helm-configuration-for-blueprints)
4. [Core Concepts](#core-concepts)
5. [Custom YAML Tags](#custom-yaml-tags)
6. [Working Examples](#working-examples)
7. [Blueprint Development Methodology](#blueprint-development-methodology)
8. [Common Use Cases](#common-use-cases)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [Quick Reference](#quick-reference)

---

## Basic Structure

### Blueprint YAML Anatomy

Every authentik blueprint follows this basic structure:

```yaml
# yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
version: 1
metadata:
  name: "Blueprint Name"
  labels:
    blueprints.goauthentik.io/instantiate: "true"

context: {}

entries:
  - model: authentik_core.application
    state: present
    identifiers:
      slug: "my-app"
    attrs:
      name: "My Application"
      # ... other attributes
```

### Required Components

| Component | Required | Description |
|-----------|----------|-------------|
| `version` | ✅ | Blueprint format version (currently `1`) |
| `entries` | ✅ | List of objects to create/manage |
| `metadata.name` | ✅ | Human-readable blueprint name |
| `context` | ❌ | Default context variables |
| `metadata.labels` | ❌ | Special blueprint configuration labels |

### Special Labels

| Label | Purpose |
|-------|---------|
| `blueprints.goauthentik.io/instantiate: "true"` | Auto-apply blueprint on discovery |
| `blueprints.goauthentik.io/system: "true"` | Mark as system blueprint |
| `blueprints.goauthentik.io/description: "text"` | Blueprint description |

---

## Deployment Patterns

### Kubernetes ConfigMap Pattern (Recommended)

This is the pattern used in your working blueprints. It provides automatic discovery and application.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-blueprint
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  blueprint.yaml: |
    # yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
    version: 1
    metadata:
      name: "My Blueprint"
      labels:
        blueprints.goauthentik.io/instantiate: "true"
    
    context: {}
    
    entries:
      # Your blueprint entries here
```

### Key Benefits

- ✅ **Automatic Discovery**: Authentik automatically detects and applies blueprints
- ✅ **Kubernetes Native**: Deployed using standard Kubernetes resources
- ✅ **Version Control**: Can be managed in Git alongside other manifests
- ✅ **Monitoring**: Changes trigger automatic reapplication (every 60 minutes + file watchers)

### Prerequisites

1. Authentik namespace must exist
2. Blueprint ConfigMaps must be applied **BEFORE** deploying Authentik with Helm
3. Proper labels must be set for automatic discovery
4. **Blueprint names must be listed in Helm values** under `blueprints.configMaps`

---

## Helm Configuration for Blueprints

### Connecting ConfigMaps to Authentik

For blueprint ConfigMaps to be discovered and applied by Authentik, they **must be explicitly listed** in the Helm values configuration. This is a crucial step that connects your deployed ConfigMaps to the running Authentik instance.

### Helm Values Configuration

Add the following to your Authentik Helm values file (e.g., `values.yaml` or `values-authentik.yaml`):

```yaml
# Blueprint system configuration
blueprints:
  # List of ConfigMaps containing blueprints
  # Only keys ending with .yaml will be discovered and applied
  configMaps:
    - "whoami-forward-auth-blueprint"        # Proxy authentication setup
    - "openwebui-authentik-blueprint"         # OAuth2/OIDC application setup
    - "users-groups-test-blueprint"           # Test blueprint for users and groups
    # Add your blueprint ConfigMap names here
```

### Complete Deployment Workflow

```bash
# 1. Deploy blueprint ConfigMaps FIRST (before Authentik)
kubectl apply -f manifests/073-authentik-whoami-blueprint.yaml
kubectl apply -f manifests/074-authentik-openwebui-blueprint-hardcoded.yaml
kubectl apply -f manifests/072-authentik-users-groups-blueprint.yaml

# 2. Verify ConfigMaps are created
kubectl get configmaps -n authentik -l app.kubernetes.io/component=blueprint

# 3. Deploy/upgrade Authentik with Helm (with blueprint references in values)
helm upgrade --install authentik authentik/authentik \
  -n authentik \
  -f values-authentik.yaml  # Contains the blueprints.configMaps configuration

# 4. Monitor blueprint application
kubectl logs -n authentik deployment/authentik-server | grep -i blueprint
```

### Blueprint Discovery Process

1. **ConfigMap Creation**: Blueprint ConfigMaps are deployed to the `authentik` namespace
2. **Helm Reference**: ConfigMap names are listed in `blueprints.configMaps` in Helm values
3. **Authentik Startup**: When Authentik starts, it reads the configured ConfigMap list
4. **Blueprint Loading**: Authentik loads and applies blueprints from the referenced ConfigMaps
5. **Automatic Reapplication**: Changes to ConfigMaps trigger reapplication (monitored every 60 minutes)

### Key Configuration Rules

| Rule | Description | Example |
|------|-------------|----------|
| **Exact Name Match** | ConfigMap names in Helm values must **exactly match** deployed ConfigMap names | `configMaps: ["openwebui-authentik-blueprint"]` |
| **YAML Files Only** | Only data keys ending with `.yaml` are processed | `data: { "openwebui.yaml": "...", "readme.txt": "..." }` ← Only `openwebui.yaml` processed |
| **Namespace Consistency** | ConfigMaps must be in the same namespace as Authentik | Both in `authentik` namespace |
| **Deploy Before Helm** | ConfigMaps must exist **before** Authentik deployment | `kubectl apply -f blueprints/` then `helm install` |

### Example Complete Helm Values

```yaml
# values-authentik.yaml
authentik:
  secret_key: "your-secret-key-here"
  postgresql:
    password: "your-pg-password"

# Blueprint system configuration
blueprints:
  configMaps:
    # Application blueprints
    - "whoami-forward-auth-blueprint"          # Forward auth proxy setup
    - "openwebui-authentik-blueprint"           # OAuth2/OIDC for OpenWebUI
    - "grafana-saml-blueprint"                  # SAML setup for Grafana
    
    # User management blueprints  
    - "users-groups-test-blueprint"             # Test users and departments
    - "ldap-import-blueprint"                   # LDAP user synchronization
    
    # Flow customization blueprints
    - "custom-login-flow-blueprint"             # Custom authentication flow
    - "mfa-enforcement-blueprint"               # Multi-factor authentication

# Other Authentik configuration...
image:
  tag: "2024.8.3"

postgresql:
  enabled: true
  auth:
    postgresPassword: "your-pg-password"
    database: "authentik"

redis:
  enabled: true
```

### Troubleshooting Helm Configuration

#### Blueprint Not Loading

**Symptoms**: ConfigMap exists but blueprint not applied

**Check List**:
1. **Verify ConfigMap name in Helm values**:
   ```bash
   # Check deployed ConfigMap name
   kubectl get configmaps -n authentik -l app.kubernetes.io/component=blueprint
   
   # Compare with Helm values
   helm get values authentik -n authentik
   ```

2. **Check ConfigMap data keys**:
   ```bash
   kubectl describe configmap openwebui-authentik-blueprint -n authentik
   # Look for .yaml files in data section
   ```

3. **Verify Authentik can read ConfigMaps**:
   ```bash
   kubectl logs -n authentik deployment/authentik-server | grep -i "configmap\|blueprint"
   ```

#### Common Configuration Mistakes

| Issue | Wrong | Correct |
|-------|-------|----------|
| **Name Mismatch** | `configMaps: ["openwebui-blueprint"]` | `configMaps: ["openwebui-authentik-blueprint"]` |
| **Missing Quotes** | `configMaps: [openwebui-authentik-blueprint]` | `configMaps: ["openwebui-authentik-blueprint"]` |
| **Wrong Data Key** | `data: { "blueprint.yml": "..." }` | `data: { "blueprint.yaml": "..." }` |
| **Deploy Order** | Helm first, then ConfigMaps | ConfigMaps first, then Helm |

### Blueprint Updates and Redeployment

When updating blueprints:

```bash
# Update blueprint ConfigMaps
kubectl apply -f manifests/074-authentik-openwebui-blueprint-hardcoded.yaml

# Authentik automatically detects changes (within 60 minutes)
# Or force immediate reapplication:
kubectl rollout restart deployment/authentik-server -n authentik
```

**Note**: New blueprints require updating Helm values and redeploying Authentik, but existing blueprint changes are automatically detected.

---

## Core Concepts

### Models

Authentik blueprints work with Django models. Each entry specifies a model to create or modify:

| Common Models | Purpose |
|---------------|---------|
| `authentik_core.application` | Applications |
| `authentik_core.user` | Users |
| `authentik_core.group` | Groups |
| `authentik_providers_proxy.proxyprovider` | Proxy providers |
| `authentik_providers_oauth2.oauth2provider` | OAuth2/OIDC providers |
| `authentik_outposts.outpost` | Outposts |
| `authentik_flows.flow` | Authentication flows |

### States

| State | Behavior |
|-------|----------|
| `present` (default) | Keep object in sync with definition |
| `created` | Create object if it doesn't exist, don't modify if it exists |
| `absent` | Delete the object |

### Identifiers vs Attributes

- **Identifiers**: Unique fields used to find existing objects
- **Attributes**: Properties to set on the object

```yaml
entries:
  - model: authentik_core.application
    identifiers:
      slug: "my-app"  # Used to find the object
    attrs:
      name: "My App"  # Properties to set
      meta_launch_url: "https://app.example.com"
```

### Object Relationships

Objects can reference each other using special tags:

```yaml
entries:
  # Create provider first
  - model: authentik_providers_proxy.proxyprovider
    identifiers:
      name: "my-provider"
    # ...

  # Reference provider in application
  - model: authentik_core.application
    identifiers:
      slug: "my-app"
    attrs:
      provider: !Find [authentik_providers_proxy.proxyprovider, [name, my-provider]]
```

---

## Custom YAML Tags

### !Find - Lookup Objects

Find objects by their attributes and return their primary key:

```yaml
provider: !Find [authentik_providers_proxy.proxyprovider, [name, my-provider]]
flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
```

### !KeyOf - Reference by ID

Reference objects defined in the same blueprint by their `id`:

```yaml
entries:
  - model: authentik_flows.flow
    identifiers:
      slug: "my-flow"
    id: flow  # Set an ID
    
  - model: authentik_flows.flowstagebinding
    attrs:
      target: !KeyOf flow  # Reference by ID
```

### !Context - Use Variables

Access context variables (useful for parameterized blueprints):

```yaml
context:
  app_name: "MyApp"

entries:
  - model: authentik_core.application
    attrs:
      name: !Context app_name
```

### !Format - String Formatting

Format strings with variables:

```yaml
name: !Format ["%s-provider", !Context app_name]
```

### !If - Conditional Logic

Conditionally include configuration:

```yaml
attrs:
  enabled: !If [!Context production, true, false]
```

### !Env - Environment Variables

Use environment variables:

```yaml
password: !Env SECRET_PASSWORD
```

### !File - File Contents

Read file contents:

```yaml
certificate: !File /path/to/cert.pem
```

---

## Working Examples

### Example 1: Application with Proxy Provider

This example creates a complete forward authentication setup for a whoami application:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: whoami-forward-auth-blueprint
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  whoami-simple.yaml: |
    version: 1
    metadata:
      name: "Complete Whoami Forward Auth Setup"
      labels:
        blueprints.goauthentik.io/instantiate: "true"
    
    context: {}
    
    entries:
      # Create the proxy provider first
      - model: authentik_providers_proxy.proxyprovider
        state: present
        identifiers:
          name: "whoami-provider"
        attrs:
          name: "whoami-provider"
          mode: "forward_single"
          external_host: "http://whoami.localhost"
          access_token_validity: "hours=24"
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          
      # Create the application
      - model: authentik_core.application
        state: present
        identifiers:
          slug: "whoami"
        attrs:
          name: "whoami"
          provider: !Find [authentik_providers_proxy.proxyprovider, [name, whoami-provider]]
          
      # Assign to outpost
      - model: authentik_outposts.outpost
        state: present
        identifiers:
          name: "authentik Embedded Outpost"
        attrs:
          providers:
            - !Find [authentik_providers_proxy.proxyprovider, [name, whoami-provider]]
```

### Example 2: OAuth2/OIDC Application (OpenWebUI)

This example demonstrates a complete OAuth2/OIDC setup for OpenWebUI, **developed using the reverse engineering methodology** described later in this document:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openwebui-authentik-blueprint
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  openwebui.yaml: |
    # yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
    version: 1
    metadata:
      name: "Complete OpenWebUI OAuth2/OIDC Setup"
      labels:
        blueprints.goauthentik.io/instantiate: "true"
    
    context: {}
    
    entries:
      # Create the OAuth2/OIDC provider first (referenced by application)
      - model: authentik_providers_oauth2.oauth2provider
        state: present
        identifiers:
          name: openwebui-dev-provider
        attrs:
          name: openwebui-dev-provider
          client_type: confidential
          client_id: 1c37QuM0qm0g2BzdLbhppVwmUwUUrhmB83e9inEe
          client_secret: BngAuX1zthtYnyAxPePAwyTqDxfVSq09IDRUTAonRcogYmhnfj39eBk709nKF4ej1OT7OMiJWVYIrwOrdizTFiyQxapQUEpDziPNucs5yxIciEx21PkK82IgURILL06h
          # Correct redirect URIs format matching working config
          redirect_uris:
            - matching_mode: strict
              url: http://openwebui.localhost/oauth/oidc/callback
          # Token validity settings from working config
          access_code_validity: minutes=1
          access_token_validity: minutes=5
          refresh_token_validity: days=30
          # Additional settings from working config
          sub_mode: hashed_user_id
          issuer_mode: per_provider
          include_claims_in_id_token: true
          # Flow references
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
          # Property mappings - only the 3 that are actually used in working config
          property_mappings:
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]
          
      # Create the application and link it to the provider
      - model: authentik_core.application
        state: present
        identifiers:
          slug: openwebui-dev
        attrs:
          name: openwebui-dev
          slug: openwebui-dev
          # Empty launch URL as in working config
          meta_launch_url: ""
          policy_engine_mode: any
          provider: !Find [authentik_providers_oauth2.oauth2provider, [name, openwebui-dev-provider]]
```

**Key Points from Reverse Engineering:**
- **Complex redirect URIs format** with `matching_mode: strict` is required
- **Multiple token validity settings** must be specified exactly
- **Property mappings** should only include the 3 actually used (openid, email, profile)
- **Additional OAuth2 attributes** like `sub_mode`, `issuer_mode`, `include_claims_in_id_token` are crucial
- **Empty launch URL** works better than trying to specify one

### Example 3: Users and Groups

This example creates department-based groups and test users:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: users-groups-test-blueprint
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  users-groups-test-setup.yaml: |
    version: 1
    metadata:
      name: "Test Users and Groups Setup"
    
    entries:
      # Create groups first
      - model: authentik_core.group
        state: present
        identifiers:
          name: "IT Department"
        attrs:
          name: "IT Department"
          is_superuser: false
          attributes:
            department: "IT"
            type: "department_group"
            
      # Create users and assign to groups
      - model: authentik_core.user
        state: present
        identifiers:
          username: "john.doe"
        attrs:
          username: "john.doe"
          name: "John Doe"
          email: "john.doe@company.com"
          password: "TempPassword123"
          is_active: true
          groups:
            - !Find [authentik_core.group, [name, "IT Department"]]
```

**Key Points:**
- Groups must be created before users that reference them
- Use `!Find` to assign users to groups
- Custom attributes can be added for additional metadata

---

## Blueprint Development Methodology

### When Blueprint Documentation is Insufficient

Often, authentik's blueprint documentation lacks specific examples for complex configurations. This section describes a proven methodology for **reverse engineering working configurations** into blueprints.

### The Manual Setup + Export Method

This approach involves:
1. **Manual Configuration** in the Authentik UI
2. **Export the Working Configuration** using Django management commands
3. **Analyze the Export** to understand the correct structure
4. **Create the Blueprint** based on the working configuration

### Step-by-Step Process

#### 1. Create Manual Configuration

Set up the desired configuration manually through the Authentik web UI:

```bash
# Example: OpenWebUI OAuth2 Setup
# 1. Navigate to authentik.localhost
# 2. Applications > Applications > Create with Provider
# 3. Configure Provider Type: OAuth2/OpenID Connect
# 4. Set all required parameters through the UI
# 5. Test the configuration works
```

#### 2. Export Working Configuration

Use Django management commands to export the working configuration:

```bash
# Log into the authentik worker pod
kubectl exec -it -n authentik deployment/authentik-worker -- /bin/bash

# Export all blueprints to see the structure
python manage.py export_blueprint > /tmp/all-blueprints.yaml

# Export specific object types
python manage.py dumpdata authentik_providers_oauth2.oauth2provider --format=yaml > /tmp/oauth2-providers.yaml
python manage.py dumpdata authentik_core.application --format=yaml > /tmp/applications.yaml

# Find the object ID using Django shell
python manage.py shell -c "
from authentik.providers.oauth2.models import OAuth2Provider
from authentik.core.models import Application

# Find your provider
provider = OAuth2Provider.objects.get(name='openwebui-dev-provider')
print(f'Provider ID: {provider.pk}')
print(f'Client Type: {provider.client_type}')
print(f'Redirect URIs: {provider.redirect_uris}')

# Find your application
app = Application.objects.get(slug='openwebui-dev')
print(f'Application ID: {app.pk}')
"

# Export specific object by ID
python manage.py dumpdata authentik_providers_oauth2.oauth2provider --format=yaml --pk=4 > /tmp/specific-provider.yaml
```

#### 3. Analyze Export Files

Copy the export files from the pod and analyze them:

```bash
# Copy exports to local machine
kubectl cp authentik/deployment/authentik-worker:/tmp/oauth2-providers.yaml ./oauth2-export.yaml
kubectl cp authentik/deployment/authentik-worker:/tmp/applications.yaml ./app-export.yaml

# Examine the structure
cat oauth2-export.yaml
cat app-export.yaml
```

#### 4. Identify Key Differences

Compare your failed blueprint attempts with the working export:

```yaml
# Working export shows:
redirect_uris:
  - url: http://openwebui.localhost/oauth/oidc/callback
    matching_mode: strict

# vs failed blueprint had:
redirect_uris: 
  - http://openwebui.localhost/oauth/oidc/callback
```

#### 5. Create Corrected Blueprint

Build the blueprint using the exact working configuration format:

```yaml
# Use the complex object format that actually works
redirect_uris:
  - matching_mode: strict
    url: http://openwebui.localhost/oauth/oidc/callback

# Include all the hidden settings from exports
access_code_validity: minutes=1
access_token_validity: minutes=5  # This was missing!
refresh_token_validity: days=30
sub_mode: hashed_user_id
issuer_mode: per_provider
include_claims_in_id_token: true
```

### Export Commands Quick Reference

```bash
# Essential export commands for blueprint development:

# 1. Get into authentik worker pod
kubectl exec -it -n authentik deployment/authentik-worker -- /bin/bash

# 2. Export all objects (big file, useful for finding relationships)
python manage.py export_blueprint > /tmp/all-blueprints.yaml

# 3. Export specific model types
python manage.py dumpdata authentik_providers_oauth2.oauth2provider --format=yaml > /tmp/oauth2-providers.yaml
python manage.py dumpdata authentik_providers_proxy.proxyprovider --format=yaml > /tmp/proxy-providers.yaml
python manage.py dumpdata authentik_core.application --format=yaml > /tmp/applications.yaml
python manage.py dumpdata authentik_core.user --format=yaml > /tmp/users.yaml
python manage.py dumpdata authentik_core.group --format=yaml > /tmp/groups.yaml

# 4. Find specific object IDs using Django shell
python manage.py shell -c "
from authentik.providers.oauth2.models import OAuth2Provider
# Replace with your object query
obj = OAuth2Provider.objects.get(name='your-provider-name')
print(f'Object ID: {obj.pk}')
print(f'Key attributes: {obj.__dict__}')
"

# 5. Export specific object by ID
python manage.py dumpdata model_name --format=yaml --pk=object_id > /tmp/specific-object.yaml

# 6. Copy files back to local machine
kubectl cp authentik/deployment/authentik-worker:/tmp/file.yaml ./local-file.yaml
```

### Common Models for Export

| Model Path | Purpose | Export Command |
|------------|---------|----------------|
| `authentik_providers_oauth2.oauth2provider` | OAuth2/OIDC providers | `python manage.py dumpdata authentik_providers_oauth2.oauth2provider --format=yaml` |
| `authentik_providers_proxy.proxyprovider` | Proxy providers | `python manage.py dumpdata authentik_providers_proxy.proxyprovider --format=yaml` |
| `authentik_providers_saml.samlprovider` | SAML providers | `python manage.py dumpdata authentik_providers_saml.samlprovider --format=yaml` |
| `authentik_core.application` | Applications | `python manage.py dumpdata authentik_core.application --format=yaml` |
| `authentik_core.user` | Users | `python manage.py dumpdata authentik_core.user --format=yaml` |
| `authentik_core.group` | Groups | `python manage.py dumpdata authentik_core.group --format=yaml` |
| `authentik_flows.flow` | Flows | `python manage.py dumpdata authentik_flows.flow --format=yaml` |

### Success Indicators

You know your reverse engineering worked when:

1. **Blueprint applies without errors**
2. **Objects appear in Authentik UI**
3. **Configuration matches your manual setup exactly**
4. **Application authentication works as expected**

### Documentation Benefits

Always document your reverse engineering process:

```yaml
# Include in blueprint comments:
# This blueprint was corrected based on working manual setup:
# Export commands used to capture working config:
# kubectl exec -it -n authentik deployment/authentik-worker -- python manage.py dumpdata authentik_providers_oauth2.oauth2provider --format=yaml --pk=4
#
# Manual setup steps for reference:
# 1. Applications > Applications > Create with Provider
# 2. Name: "openwebui-dev"
# [... detailed manual steps ...]
```

This methodology ensures you can reliably create blueprints for any Authentik configuration, regardless of documentation gaps.

---

## Common Use Cases

### 1. OIDC Application Setup (Simple)

```yaml
entries:
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: "my-oidc-app-provider"
    attrs:
      name: "my-oidc-app-provider"
      client_type: "confidential"
      client_id: "my-oidc-app"
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      
  - model: authentik_core.application
    identifiers:
      slug: "my-oidc-app"
    attrs:
      name: "My OIDC App"
      provider: !Find [authentik_providers_oauth2.oauth2provider, [name, my-oidc-app-provider]]
```

### 2. SAML Application Setup

```yaml
entries:
  - model: authentik_providers_saml.samlprovider
    identifiers:
      name: "my-saml-app-provider"
    attrs:
      name: "my-saml-app-provider"
      acs_url: "https://app.example.com/saml/acs"
      issuer: "https://auth.example.com"
      sp_binding: "post"
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      
  - model: authentik_core.application
    identifiers:
      slug: "my-saml-app"
    attrs:
      name: "My SAML App"
      provider: !Find [authentik_providers_saml.samlprovider, [name, my-saml-app-provider]]
```

### 3. Bulk User Creation

```yaml
entries:
  - model: authentik_core.group
    identifiers:
      name: "Employees"
    attrs:
      name: "Employees"
      
  # Use context for parameterized user creation
  - model: authentik_core.user
    identifiers:
      username: !Context username
    attrs:
      username: !Context username
      email: !Context email
      name: !Context full_name
      is_active: true
      groups:
        - !Find [authentik_core.group, [name, "Employees"]]
```

### 4. Custom Flow Creation

```yaml
entries:
  - model: authentik_flows.flow
    identifiers:
      slug: "custom-auth-flow"
    id: custom_flow
    attrs:
      name: "Custom Authentication"
      title: "Custom Login"
      designation: "authentication"
      
  - model: authentik_stages_identification.identificationstage
    identifiers:
      name: "custom-identification"
    id: identification_stage
    
  - model: authentik_flows.flowstagebinding
    identifiers:
      target: !KeyOf custom_flow
      stage: !KeyOf identification_stage
      order: 10
```

---

## Best Practices

### File Organization

1. **Use descriptive file names**: `073-authentik-whoami-blueprint.yaml`
2. **Include comprehensive headers** with description, usage, and prerequisites
3. **Group related configurations** in single blueprints when logical

### Documentation Standards

```yaml
# File: manifests/XXX-authentik-[purpose]-blueprint.yaml
#
# Description:
# Brief description of what this blueprint does
#
# Usage:
#   kubectl apply -f XXX-authentik-[purpose]-blueprint.yaml
#
# Prerequisites:
# - List prerequisites here
#
# This blueprint replaces these manual UI steps:
# 1. Step 1
# 2. Step 2
# ...
#
# Development notes:
# - Include reverse engineering details if used
# - Document export commands used
# - Note any special configuration requirements
```

### Dependency Management

1. **Order matters**: Create referenced objects first
2. **Use !Find for cross-references**: Don't hardcode IDs
3. **Consider using !KeyOf** for objects in the same blueprint

### Security Considerations

1. **Avoid hardcoded secrets** in blueprints
2. **Use !Env for sensitive data**: `password: !Env SECRET_PASSWORD`
3. **Mark test blueprints clearly**: Include environment indicators
4. **Use proper RBAC**: Don't give excessive permissions

### Testing and Validation

1. **Use schema validation**: Include schema comment at top of files
2. **Test in development first**: Use separate namespaces/environments
3. **Verify object creation**: Check authentik UI after applying
4. **Monitor blueprint status**: Use kubectl to check ConfigMap status

---

## Troubleshooting

### Common Issues

#### Blueprint Not Applied

**Symptoms**: Blueprint exists but objects aren't created

**Solutions**:
1. Check labels on ConfigMap:
   ```yaml
   labels:
     blueprints.goauthentik.io/instantiate: "true"
   ```
2. Verify authentik can read the ConfigMap
3. Check authentik logs for blueprint errors

#### Object Not Found Errors

**Symptoms**: `!Find` or `!KeyOf` tags failing

**Solutions**:
1. Ensure referenced objects are created first
2. Check identifiers match exactly
3. Verify object actually exists in authentik

#### Invalid Blueprint Format

**Symptoms**: Blueprint validation errors

**Solutions**:
1. Use schema validation in your editor
2. Check YAML syntax
3. Verify all required fields are present
4. **Use the reverse engineering method** to get correct format

#### Complex Configuration Failures

**Symptoms**: Blueprint applies but configuration doesn't work

**Solutions**:
1. **Apply the reverse engineering methodology**:
   - Set up manually in UI
   - Export working configuration
   - Compare with your blueprint
   - Update blueprint with exact working values
2. Check for missing required attributes
3. Verify object relationships are correct

#### Permission Denied

**Symptoms**: Blueprint can't create objects

**Solutions**:
1. Check authentik service account permissions
2. Verify RBAC configuration
3. Check namespace permissions

### Advanced Debugging

#### Using Export Commands for Debugging

When blueprints fail, use exports to understand the current state:

```bash
# Check what actually got created
kubectl exec -it -n authentik deployment/authentik-worker -- python manage.py shell -c "
from authentik.providers.oauth2.models import OAuth2Provider
from authentik.core.models import Application

# List all providers to see what exists
for p in OAuth2Provider.objects.all():
    print(f'Provider: {p.name} (ID: {p.pk})')

# List all applications
for a in Application.objects.all():
    print(f'Application: {a.name} (Slug: {a.slug})')
"

# Export failed/partial configuration
python manage.py dumpdata authentik_providers_oauth2.oauth2provider --format=yaml --pk=problem_id > /tmp/debug.yaml
```

### Useful Commands

```bash
# Check ConfigMap status
kubectl get configmap -n authentik

# View ConfigMap contents
kubectl describe configmap whoami-forward-auth-blueprint -n authentik

# Check authentik logs for blueprint processing
kubectl logs -n authentik deployment/authentik-server | grep -i blueprint

# Check worker logs for Django errors
kubectl logs -n authentik deployment/authentik-worker

# Validate YAML locally
yamllint blueprint.yaml
```

---

## Quick Reference

### Essential Models

| Model | Purpose | Key Identifiers |
|-------|---------|-----------------|
| `authentik_core.application` | Applications | `slug` |
| `authentik_core.user` | Users | `username` |
| `authentik_core.group` | Groups | `name` |
| `authentik_providers_proxy.proxyprovider` | Proxy providers | `name` |
| `authentik_providers_oauth2.oauth2provider` | OIDC providers | `name` |
| `authentik_providers_saml.samlprovider` | SAML providers | `name` |
| `authentik_outposts.outpost` | Outposts | `name` |
| `authentik_flows.flow` | Flows | `slug` |

### Common Attributes

#### Application (`authentik_core.application`)
```yaml
attrs:
  name: "App Name"
  slug: "app-slug"
  meta_launch_url: "https://app.example.com"  # Can be empty ""
  provider: !Find [provider_model, [name, provider-name]]
  policy_engine_mode: any
```

#### OAuth2 Provider (`authentik_providers_oauth2.oauth2provider`)
```yaml
attrs:
  name: "provider-name"
  client_type: "confidential"  # or "public"
  client_id: "your-client-id"
  client_secret: "your-client-secret"
  redirect_uris:
    - matching_mode: strict  # Important: complex format often required
      url: "https://app.example.com/callback"
  access_code_validity: "minutes=1"
  access_token_validity: "hours=1"  # Or minutes=5 for short-lived
  refresh_token_validity: "days=30"
  sub_mode: "hashed_user_id"
  issuer_mode: "per_provider"
  include_claims_in_id_token: true
  authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
  invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
  signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
  property_mappings:
    - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
    - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]
    - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]
```

#### Proxy Provider (`authentik_providers_proxy.proxyprovider`)
```yaml
attrs:
  name: "provider-name"
  mode: "forward_single"  # or "forward_domain", "proxy"
  external_host: "https://app.example.com"
  authorization_flow: !Find [authentik_flows.flow, [slug, flow-slug]]
  access_token_validity: "hours=24"
```

#### User (`authentik_core.user`)
```yaml
attrs:
  username: "username"
  email: "user@example.com"
  name: "Full Name"
  password: "password"
  is_active: true
  groups:
    - !Find [authentik_core.group, [name, "Group Name"]]
```

#### Group (`authentik_core.group`)
```yaml
attrs:
  name: "Group Name"
  is_superuser: false
  attributes:
    custom_field: "value"
```

### Template Checklist

- [ ] Schema comment at top
- [ ] Version set to 1
- [ ] Metadata name defined
- [ ] Proper instantiate label
- [ ] All dependencies ordered correctly
- [ ] Identifiers use unique fields
- [ ] States defined appropriately
- [ ] Documentation header complete
- [ ] Reverse engineering methodology documented if used

### File Template

```yaml
# File: manifests/XXX-authentik-[purpose]-blueprint.yaml
#
# Description: [What this blueprint does]
# Usage: kubectl apply -f XXX-authentik-[purpose]-blueprint.yaml
# Prerequisites: [List prerequisites]
#
# Manual setup steps for reference:
# [Include detailed UI steps for fallback/troubleshooting]
#
# Development methodology:
# [If reverse engineered, include export commands used]

apiVersion: v1
kind: ConfigMap
metadata:
  name: [blueprint-name]
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  blueprint.yaml: |
    # yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
    version: 1
    metadata:
      name: "[Blueprint Name]"
      labels:
        blueprints.goauthentik.io/instantiate: "true"
    
    context: {}
    
    entries:
      # Your entries here
```

---

## Resources

- [Official Authentik Blueprint Documentation](https://docs.goauthentik.io/customize/blueprints/)
- [Blueprint Schema](https://goauthentik.io/blueprints/schema.json)
- [Example Blueprints](https://github.com/goauthentik/authentik/tree/main/blueprints/example)
- [YAML Custom Tags](https://docs.goauthentik.io/customize/blueprints/v1/tags/)

---

*Last updated: September 2025*
