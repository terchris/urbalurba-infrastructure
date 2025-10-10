# Example: How to Use Red Cross Shared Schemas

This example shows all the common patterns for using the shared schemas in your APIs.

```yaml
openapi: 3.0.0
info:
  title: Red Cross Branch Management API - Example
  version: 1.0.0
  description: |
    Complete example showing how to use Red Cross shared schemas.
    
    📚 Schema Reference:
    - Basic fields: ../schemas/v1/fields/
    - Composite schemas: ../schemas/v1/schemas/

servers:
  - url: https://localhost:7001
    description: Development server

paths:
  /branches:
    get:
      summary: Get all branches
      operationId: GetBranches
      parameters:
        - name: county
          in: query
          schema:
            # ✅ Use basic field for query parameter
            $ref: '../schemas/v1/fields/county.yaml#/components/schemas/County'
        - name: branchType
          in: query
          schema:
            $ref: '../schemas/v1/fields/branch-type.yaml#/components/schemas/BranchType'
      responses:
        '200':
          description: List of branches
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/BranchSummary'

    post:
      summary: Create new branch
      operationId: CreateBranch
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateBranchRequest'
      responses:
        '201':
          description: Branch created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BranchDetail'

  /branches/{branchId}:
    get:
      summary: Get branch by ID
      operationId: GetBranch
      parameters:
        - name: branchId
          in: path
          required: true
          schema:
            # ✅ Use basic field for path parameter
            $ref: '../schemas/v1/fields/branch-id.yaml#/components/schemas/BranchId'
      responses:
        '200':
          description: Branch details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BranchDetail'
        '404':
          description: Branch not found

components:
  schemas:
    # Pattern 1: Extend base schema with allOf
    BranchDetail:
      allOf:
        # ✅ Start with base branch schema
        - $ref: '../schemas/v1/schemas/branch-base.yaml#/components/schemas/BranchBase'
        # ✅ Add additional properties
        - type: object
          properties:
            address:
              # ✅ Use composite address schema
              $ref: '../schemas/v1/schemas/address.yaml#/components/schemas/Address'
            communication:
              # ✅ Use communication channels schema
              $ref: '../schemas/v1/schemas/communication-channels.yaml#/components/schemas/CommunicationChannels'
            location:
              # ✅ Use basic geo-location field
              $ref: '../schemas/v1/fields/geo-location.yaml#/components/schemas/GeoLocation'
            organizationNumber:
              $ref: '../schemas/v1/fields/organization-number.yaml#/components/schemas/OrganizationNumber'
            county:
              $ref: '../schemas/v1/fields/county.yaml#/components/schemas/County'
            municipality:
              $ref: '../schemas/v1/fields/municipality.yaml#/components/schemas/Municipality'
            activities:
              type: array
              items:
                # ✅ Use global activity schema
                $ref: '../schemas/v1/schemas/global-activity.yaml#/components/schemas/GlobalActivity'

    # Pattern 2: Simple extension with just base schema
    BranchSummary:
      allOf:
        - $ref: '../schemas/v1/schemas/branch-base.yaml#/components/schemas/BranchBase'
        - type: object
          properties:
            county:
              $ref: '../schemas/v1/fields/county.yaml#/components/schemas/County'
            municipality:
              $ref: '../schemas/v1/fields/municipality.yaml#/components/schemas/Municipality'

    # Pattern 3: Request schema combining various shared types
    CreateBranchRequest:
      type: object
      required: [branchName, branchType, address]
      properties:
        branchName:
          $ref: '../schemas/v1/fields/branch-name.yaml#/components/schemas/BranchName'
        branchType:
          $ref: '../schemas/v1/fields/branch-type.yaml#/components/schemas/BranchType'
        address:
          $ref: '../schemas/v1/schemas/address.yaml#/components/schemas/Address'
        communication:
          $ref: '../schemas/v1/schemas/communication-channels.yaml#/components/schemas/CommunicationChannels'
        organizationNumber:
          $ref: '../schemas/v1/fields/organization-number.yaml#/components/schemas/OrganizationNumber'
        location:
          $ref: '../schemas/v1/fields/geo-location.yaml#/components/schemas/GeoLocation'

    # Pattern 4: Custom schema with shared field validation
    BranchUpdateRequest:
      type: object
      properties:
        # ✅ Each field uses shared validation rules
        newName:
          $ref: '../schemas/v1/fields/branch-name.yaml#/components/schemas/BranchName'
        newAddress:
          $ref: '../schemas/v1/schemas/address.yaml#/components/schemas/Address'
        updatedCommunication:
          $ref: '../schemas/v1/schemas/communication-channels.yaml#/components/schemas/CommunicationChannels'

    # Pattern 5: Error responses can also use shared types
    ErrorResponse:
      type: object
      required: [message]
      properties:
        message:
          type: string
          description: Error message
        branchId:
          # ✅ Even in errors, use shared types for consistency
          $ref: '../schemas/v1/fields/branch-id.yaml#/components/schemas/BranchId'
        timestamp:
          type: string
          format: date-time
```

## Key Benefits Demonstrated

✅ **Consistent Validation**: All branch IDs follow the same L999 pattern across APIs
✅ **Type Safety**: Generated C# code will share common types
✅ **Reusability**: Address schema can be used in member APIs, activity APIs, etc.
✅ **Maintainability**: Change email validation in one place, affects all APIs
✅ **Documentation**: Consistent field descriptions across all APIs

## Generated C# Code Example

When you generate clients from APIs using these schemas, you get:

```csharp
// Shared across ALL your API clients
public class BranchId 
{
    [RegularExpression(@"^L[0-9]{3}$")]
    public string Value { get; set; }
}

public class Address
{
    [MaxLength(100)]
    public string AddressLine1 { get; set; }
    
    [MaxLength(100)]
    public string AddressLine2 { get; set; }
    
    public NorwegianPostalCode PostalCode { get; set; }
    
    [MaxLength(50)]
    public string PostOffice { get; set; }
}

// Your API-specific classes extend the shared types
public class BranchDetail : BranchBase
{
    public Address Address { get; set; }
    public CommunicationChannels Communication { get; set; }
    // etc.
}
```