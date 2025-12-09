# Changelog

All notable changes to the Red Cross shared schemas will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-09

### Added
- Initial release of Red Cross shared OpenAPI schemas
- **Field types (v1):**
  - `BranchId` - Unique branch identifier with L### pattern
  - `BranchName` - Official branch name with Norwegian character support
  - `BranchNumber` - 7-digit internal branch number
  - `BranchType` - Enum for organization unit types
  - `Email` - RFC-compliant email address validation
  - `NorwegianPhoneNumber` - +47 format validation
  - `NorwegianPostalCode` - 4-digit postal code validation
  - `OrganizationNumber` - 9-digit Norwegian organization number
  - `OrganizationLevel` - Internal organization level code
  - `County` - Norwegian county (fylke) with character validation
  - `Municipality` - Norwegian municipality (kommune) with character validation
  - `GeoLocation` - GeoJSON Feature format for coordinates
  - `GlobalActivityId` - UUID for standard Red Cross activities
  - `GlobalActivityName` - Standard activity name (max 50 chars)
  - `MemberStatus` - Boolean member status indicator
  - `VolunteerStatus` - Boolean volunteer status indicator
  - `Web` - Website URL with protocol validation
  - `PrivacyMaskedString` - String with privacy masking support

- **Entity schemas (v1):**
  - `Branch` - Complete branch entity with all properties
  - `CreateBranchRequest` - Request schema for branch creation
  - `UpdateBranchRequest` - Request schema for branch updates

- **Documentation:**
  - Usage examples for consultants
  - Complete field reference table
  - Reference patterns and anti-patterns
  - Integration guidelines

### Notes
- All schemas include validation patterns and examples
- Norwegian character support (æ, ø, å) included where appropriate
- GeoJSON compliance for geographic data
- Privacy-aware field definitions
