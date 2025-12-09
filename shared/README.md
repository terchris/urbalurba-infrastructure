# Urbalurba Shared Schemas

This directory contains the shared schema definitions for Urbalurba APIs following the API-First development approach.

## Directory Structure

```
shared/
├── schemas/
│   └── v1/
│       ├── fields/               # Basic field types
│       │   ├── branch-id.yaml
│       │   ├── email.yaml
│       │   ├── postal-code.yaml
│       │   └── ... (18 field files)
│       └── schemas/              # Composite schemas
│           ├── address.yaml      # Uses postal-code
│           ├── branch-base.yaml  # Uses branch fields
│           ├── communication-channels.yaml
│           └── global-activity.yaml
├── examples/                     # Usage examples
└── README.md                     # This file
```

## Schema Hierarchy

### Level 1: Basic Fields (`fields/v1/`)
Single, reusable field types with validation rules:
- `branch-id.yaml` - Branch identifier (L999 format)
- `email.yaml` - Email addresses with validation
- `postal-code.yaml` - Norwegian 4-digit postal codes
- `norwegian-phone.yaml` - Phone numbers with +47 format
- And 14 more field types...

### Level 2: Composite Schemas (`schemas/v1/`)
Complex objects combining multiple field types:
- `address.yaml` - Norwegian postal address format
- `branch-base.yaml` - Core branch information
- `communication-channels.yaml` - Contact information
- `global-activity.yaml` - Activity definitions

## Usage in APIs

Reference these schemas in your OpenAPI specifications:

### Using Basic Fields
```yaml
properties:
  branchId:
    $ref: '../shared/schemas/v1/fields/branch-id.yaml#/components/schemas/BranchId'
  contactEmail:
    $ref: '../shared/schemas/v1/fields/email.yaml#/components/schemas/Email'
```

### Using Composite Schemas
```yaml
properties:
  address:
    $ref: '../shared/schemas/v1/schemas/address.yaml#/components/schemas/Address'
  communication:
    $ref: '../shared/schemas/v1/schemas/communication-channels.yaml#/components/schemas/CommunicationChannels'
```

### Extending Base Schemas
```yaml
MyBranchInfo:
  allOf:
    - $ref: '../shared/schemas/v1/schemas/branch-base.yaml#/components/schemas/BranchBase'
    - type: object
      properties:
        customField:
          type: string
```

## Rules for Contributors

✅ **DO:**
- Always reference existing schemas instead of recreating
- Follow the established patterns for new field types
- Use semantic versioning for schema changes
- Document any breaking changes

❌ **DON'T:**
- Create duplicate field types
- Modify existing schemas without version bump
- Skip validation patterns
- Break existing API contracts

## Validation

Use NSwag to validate schemas:
```bash
# Validate individual schema
nswag validate /input:schemas/v1/fields/branch-id.yaml

# Validate all schemas
find schemas -name "*.yaml" -exec nswag validate /input:{} \;
```

For questions or changes, contact the Urbalurba API team.