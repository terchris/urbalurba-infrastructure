# Red Cross Shared OpenAPI Schemas

This repository contains the official shared OpenAPI schema definitions for Red Cross Norway APIs.

## 🚨 Important for Consultants

**This repository is READ-ONLY for external consultants!**

- ✅ **DO:** Reference these schemas in your API specifications
- ❌ **DON'T:** Modify, copy, or create custom versions of these schemas
- 🆘 **Need a new field type?** Contact the Red Cross API team

## Repository Structure

```
redcross-schemas/
├── fields/v1/              # Individual field type definitions
│   ├── branch-id.yaml      # Branch identifier
│   ├── email.yaml          # Email address
│   ├── geo-location.yaml   # Geographic coordinates
│   └── ...                 # All standard Red Cross field types
├── entities/v1/            # Complete entity schemas
│   ├── branch.yaml         # Branch entity with all properties
│   └── ...                 # Other business entities
├── examples/               # Usage examples for consultants
│   └── how-to-reference.yaml  # Shows correct reference patterns
├── README.md               # This file
└── CHANGELOG.md            # Version history
```

## How to Use These Schemas

### 1. As a Git Submodule (Recommended)

```bash
# Add as submodule to your project
git submodule add https://github.com/redcross/redcross-schemas.git shared-schemas

# Update to latest version
git submodule update --remote
```

### 2. Reference in Your OpenAPI Specs

```yaml
# In your API specification
components:
  schemas:
    MyResponse:
      type: object
      properties:
        branchId:
          $ref: '../shared-schemas/fields/v1/branch-id.yaml#/components/schemas/BranchId'
        email:
          $ref: '../shared-schemas/fields/v1/email.yaml#/components/schemas/Email'
```

### 3. Use Complete Entities

```yaml
paths:
  /branches:
    get:
      responses:
        '200':
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '../shared-schemas/entities/v1/branch.yaml#/components/schemas/Branch'
```

## Available Field Types

| Field | File | Description |
|-------|------|-------------|
| `BranchId` | `fields/v1/branch-id.yaml` | Unique branch identifier (L123 format) |
| `BranchName` | `fields/v1/branch-name.yaml` | Official branch name |
| `BranchNumber` | `fields/v1/branch-number.yaml` | Internal branch number |
| `BranchType` | `fields/v1/branch-type.yaml` | Type of organization unit |
| `Email` | `fields/v1/email.yaml` | Email address with validation |
| `NorwegianPhoneNumber` | `fields/v1/norwegian-phone.yaml` | Norwegian phone with +47 format |
| `NorwegianPostalCode` | `fields/v1/postal-code.yaml` | 4-digit Norwegian postal code |
| `OrganizationNumber` | `fields/v1/organization-number.yaml` | Norwegian org number |
| `County` | `fields/v1/county.yaml` | Norwegian county (fylke) |
| `Municipality` | `fields/v1/municipality.yaml` | Norwegian municipality (kommune) |
| `GeoLocation` | `fields/v1/geo-location.yaml` | GeoJSON coordinates |
| `GlobalActivityId` | `fields/v1/global-activity-id.yaml` | UUID for standard activities |
| `GlobalActivityName` | `fields/v1/global-activity-name.yaml` | Standard activity name |
| `MemberStatus` | `fields/v1/member-status.yaml` | Boolean member status |
| `VolunteerStatus` | `fields/v1/volunteer-status.yaml` | Boolean volunteer status |
| `Web` | `fields/v1/web.yaml` | Website URL |
| `PrivacyMaskedString` | `fields/v1/privacy-masked-string.yaml` | String that can be masked |

## Available Entities

| Entity | File | Description |
|--------|------|-------------|
| `Branch` | `entities/v1/branch.yaml` | Complete branch information |
| `CreateBranchRequest` | `entities/v1/branch.yaml` | Request for creating branch |
| `UpdateBranchRequest` | `entities/v1/branch.yaml` | Request for updating branch |

## Validation

All schemas include appropriate validation rules:
- **Patterns** for format validation (email, phone, IDs)
- **Length limits** for strings
- **Required fields** clearly marked
- **Examples** for all types

## Examples

See `examples/how-to-reference.yaml` for complete examples showing:
- ✅ Correct reference patterns
- ❌ What NOT to do
- 🔧 How to combine shared types with custom fields

## Version Policy

- **v1** - Current stable version
- Breaking changes will create new versions (v2, v3, etc.)
- Patch updates (bug fixes) maintain backward compatibility
- See `CHANGELOG.md` for detailed version history

## Support

For questions about these schemas:
- 📧 Email: api-team@redcross.no
- 📖 Documentation: [Red Cross API Guidelines](../api-first-csharp.md)
- 🐛 Issues: Contact the API team

## Contributing

**External consultants:** Contact the Red Cross API team for schema changes or additions.

**Red Cross team members:** Follow the internal schema change process documented in the team wiki.
