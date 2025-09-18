# Red Cross Authentik Test Users Package

## Overview

This document provides a complete guide for creating and managing test users in Authentik that mirror the Red Cross organizational structure found in production Okta. The goal is to provide developers with a realistic test environment that includes all Okta fields and organizational relationships while maintaining data anonymity.

This package includes:
- **Complete user specification** with all Okta fields
- **Organizational structure** mirroring Red Cross departments
- **Blueprint conversion methodology** for automated deployment
- **Implementation guide** for Authentik integration

## Table of Contents

1. [User Specification](#user-specification)
2. [Okta Field Mapping](#okta-field-mapping)
3. [Organizational Structure](#organizational-structure)
4. [Blueprint Implementation](#blueprint-implementation)
5. [Deployment Guide](#deployment-guide)
6. [Testing and Validation](#testing-and-validation)
7. [Maintenance and Updates](#maintenance-and-updates)

---

## User Specification

### User Distribution

**Total Users: 11**
- **HQ Users: 9** - Covering all major departments from the national office
- **District Users: 2** - Representing regional/district level operations

### Complete User Table

| Username | Email | Name | Department | vi_department | vi_departmentID | vi_unitname | vi_unitID | costCenter | vi_Locale | vi_StateProvince | vi_position | vi_employeeform | employeeNumber | samAccountName | managerId | manager | ManagerdisplayName | isEmployee | isVolunteer | u_start_date | u_end_date | mobilePhone | secondEmail | bankid_birthdate | bankid_nnin_altsub | bankid_altsub | bankid_verification_timestamp | bankid_user_verified | bankid_sub | bankid_firstname | bankid_lastname | AgressoDomainUser | RelationNumber | Azure_lastNonInteractiveSignInDateTime | ServiceNowManagerIdExternalID | extensionAttribute7 | u_crm_guid | streetAddress | city | zipCode | state | deliveryOffice | division | title |
|----------|-------|------|------------|---------------|-----------------|-------------|-----------|------------|-----------|------------------|-------------|-----------------|----------------|----------------|-----------|---------|-------------------|------------|-------------|--------------|------------|-------------|-------------|------------------|-------------------|---------------|------------------------------|---------------------|-------------|-----------------|----------------|-------------------|----------------|-----------------------------------|-------------------------------|-------------------|-------------|---------------|-----|--------|-------|-------------|----------|--------|
| ok1 | ok1@urbalurba.no | Ola Nordmann | Økonomi og administrasjon | Økonomi og administrasjon | N750 | Økonomi og administrasjon | #5421000#N750#N750# | N750 | Oslo | Nasjonalkontoret | Økonomi- og administrasjonsmedarbeider | 1 Fast ansatt | 25001 | 105010OK1 | 105010MGR1 | manager1@urbalurba.no | Manager Person | true | false | 01/01/2020 | | +4790012345 | ola.nordmann@example.no | 80-01-15 | 15018012345 | Pass | 2020-01-01T09:00:00 | true | 12345678-1234-1234-1234-123456789012 | Ola | Nordmann | Z94\\105010OK1 | 105010OK1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf2 | 5207a9ec-a6bf-ec11-8117-001dd8b74416 | bb0a469d-905c-ef11-bfe3-0022489bed2b | Storgata 1 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Økonomi- og administrasjonsmedarbeider |
| re1 | re1@urbalurba.no | Kari Hansen | Økonomi og administrasjon | Regnskap og rapportering | N760 | Regnskap og rapportering | #5421000#N760#N760# | N760 | Oslo | Nasjonalkontoret | Regnskapsmedarbeider | 1 Fast ansatt | 25002 | 105010RE1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/02/2020 | | +4790012346 | kari.hansen@example.no | 85-03-22 | 22038512345 | Pass | 2020-02-01T09:00:00 | true | 12345678-1234-1234-1234-123456789013 | Kari | Hansen | Z94\\105010RE1 | 105010RE1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf3 | 5207a9ec-a6bf-ec11-8117-001dd8b74417 | bb0a469d-905c-ef11-bfe3-0022489bed2c | Storgata 2 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Regnskapsmedarbeider |
| it1 | it1@urbalurba.no | Erik Larsen | Økonomi og administrasjon | IT | N770 | IT | #5421000#N770#N770# | N770 | Oslo | Nasjonalkontoret | IT Specialist | 1 Fast ansatt | 25003 | 105010IT1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/03/2020 | | +4790012347 | erik.larsen@example.no | 82-07-10 | 10078212345 | Pass | 2020-03-01T09:00:00 | true | 12345678-1234-1234-1234-123456789014 | Erik | Larsen | Z94\\105010IT1 | 105010IT1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf4 | 5207a9ec-a6bf-ec11-8117-001dd8b74418 | bb0a469d-905c-ef11-bfe3-0022489bed2d | Storgata 3 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | IT Specialist |
| hr1 | hr1@urbalurba.no | Anna Olsen | HR og organisasjonsutvikling | HR | N780 | HR | #5421000#N780#N780# | N780 | Oslo | Nasjonalkontoret | HR Medarbeider | 1 Fast ansatt | 25004 | 105010HR1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/04/2020 | | +4790012348 | anna.olsen@example.no | 88-11-05 | 05118812345 | Pass | 2020-04-01T09:00:00 | true | 12345678-1234-1234-1234-123456789015 | Anna | Olsen | Z94\\105010HR1 | 105010HR1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf5 | 5207a9ec-a6bf-ec11-8117-001dd8b74419 | bb0a469d-905c-ef11-bfe3-0022489bed2e | Storgata 4 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | HR Medarbeider |
| ko1 | ko1@urbalurba.no | Lars Andersen | Kommunikasjon og samfunn | Kommunikasjon | N790 | Kommunikasjon | #5421000#N790#N790# | N790 | Oslo | Nasjonalkontoret | Kommunikasjonsmedarbeider | 1 Fast ansatt | 25005 | 105010KO1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/05/2020 | | +4790012349 | lars.andersen@example.no | 79-09-18 | 18097912345 | Pass | 2020-05-01T09:00:00 | true | 12345678-1234-1234-1234-123456789016 | Lars | Andersen | Z94\\105010KO1 | 105010KO1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf6 | 5207a9ec-a6bf-ec11-8117-001dd8b74420 | bb0a469d-905c-ef11-bfe3-0022489bed2f | Storgata 5 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Kommunikasjonsmedarbeider |
| in1 | in1@urbalurba.no | Maria Johansen | Inntekter | Inntekter | N800 | Inntekter | #5421000#N800#N800# | N800 | Oslo | Nasjonalkontoret | Inntektsmedarbeider | 1 Fast ansatt | 25006 | 105010IN1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/06/2020 | | +4790012350 | maria.johansen@example.no | 83-12-03 | 03128312345 | Pass | 2020-06-01T09:00:00 | true | 12345678-1234-1234-1234-123456789017 | Maria | Johansen | Z94\\105010IN1 | 105010IN1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf7 | 5207a9ec-a6bf-ec11-8117-001dd8b74421 | bb0a469d-905c-ef11-bfe3-0022489bed30 | Storgata 6 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Inntektsmedarbeider |
| sr1 | sr1@urbalurba.no | Thomas Pedersen | Nasjonale programmer og beredskap | Søk og redning | N810 | Søk og redning | #5421000#N810#N810# | N810 | Oslo | Nasjonalkontoret | Beredskapsmedarbeider | 1 Fast ansatt | 25007 | 105010SR1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/07/2020 | | +4790012351 | thomas.pedersen@example.no | 81-04-14 | 14048112345 | Pass | 2020-07-01T09:00:00 | true | 12345678-1234-1234-1234-123456789018 | Thomas | Pedersen | Z94\\105010SR1 | 105010SR1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf8 | 5207a9ec-a6bf-ec11-8117-001dd8b74422 | bb0a469d-905c-ef11-bfe3-0022489bed31 | Storgata 7 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Beredskapsmedarbeider |
| ip1 | ip1@urbalurba.no | Ingrid Svendsen | Internasjonale programmer og beredskap | Technical Unit | N820 | Technical Unit | #5421000#N820#N820# | N820 | Oslo | Nasjonalkontoret | Teknisk rådgiver | 1 Fast ansatt | 25008 | 105010IP1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/08/2020 | | +4790012352 | ingrid.svendsen@example.no | 86-06-27 | 27068612345 | Pass | 2020-08-01T09:00:00 | true | 12345678-1234-1234-1234-123456789019 | Ingrid | Svendsen | Z94\\105010IP1 | 105010IP1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbf9 | 5207a9ec-a6bf-ec11-8117-001dd8b74423 | bb0a469d-905c-ef11-bfe3-0022489bed32 | Storgata 8 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Teknisk rådgiver |
| di1 | di1@urbalurba.no | Per Kristiansen | Økonomi og administrasjon | Digital innovasjon | N830 | Digital innovasjon | #5421000#N830#N830# | N830 | Oslo | Nasjonalkontoret | Digital innovasjonsrådgiver | 1 Fast ansatt | 25009 | 105010DI1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/09/2020 | | +4790012353 | per.kristiansen@example.no | 84-02-11 | 11028412345 | Pass | 2020-09-01T09:00:00 | true | 12345678-1234-1234-1234-123456789020 | Per | Kristiansen | Z94\\105010DI1 | 105010DI1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbfa | 5207a9ec-a6bf-ec11-8117-001dd8b74424 | bb0a469d-905c-ef11-bfe3-0022489bed33 | Storgata 9 | Oslo | 0155 | Nasjonalkontoret | RK Hovedkontor | 105010-001 - RK Hovedkontor | Digital innovasjonsrådgiver |
| dist1 | dist1@urbalurba.no | Bjørn Nilsen | Distriktskontor | Buskerud RK | D006 | Buskerud RK | #5421000#D006#D006# | D006 | Drammen | Distrikt | Distriktsmedarbeider | 1 Fast ansatt | 25010 | 105010DIST1 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/10/2020 | | +4790012354 | bjorn.nilsen@example.no | 87-08-25 | 25088712345 | Pass | 2020-10-01T09:00:00 | true | 12345678-1234-1234-1234-123456789021 | Bjørn | Nilsen | Z94\\105010DIST1 | 105010DIST1 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbfb | 5207a9ec-a6bf-ec11-8117-001dd8b74425 | bb0a469d-905c-ef11-bfe3-0022489bed34 | Drammensveien 1 | Drammen | 3015 | Distrikt | Buskerud RK | 105010-002 - Buskerud RK | Distriktsmedarbeider |
| dist2 | dist2@urbalurba.no | Solveig Berg | Distriktskontor | Hordaland RK | D010 | Hordaland RK | #5421000#D010#D010# | D010 | Bergen | Distrikt | Distriktsmedarbeider | 1 Fast ansatt | 25011 | 105010DIST2 | 105010OK1 | ola.nordmann@urbalurba.no | Ola Nordmann | true | false | 01/11/2020 | | +4790012355 | solveig.berg@example.no | 89-01-08 | 08018912345 | Pass | 2020-11-01T09:00:00 | true | 12345678-1234-1234-1234-123456789022 | Solveig | Berg | Z94\\105010DIST2 | 105010DIST2 | 2024-01-15T08:30:00Z | d1b50bf41ba56690825da711604bcbfc | 5207a9ec-a6bf-ec11-8117-001dd8b74426 | bb0a469d-905c-ef11-bfe3-0022489bed35 | Bryggen 1 | Bergen | 5003 | Distrikt | Hordaland RK | 105010-003 - Hordaland RK | Distriktsmedarbeider |

---

## Okta Field Mapping

### Field Categories

The user specification includes all fields found in production Okta, organized into these categories:

#### Core Identity Fields
- **username**: Unique identifier for each user (ok1, re1, it1, etc.)
- **email**: Primary email address using @urbalurba.no domain
- **name**: Full name using generic Norwegian names
- **login**: Same as email (standard Okta pattern)

#### Organizational Fields
- **department**: Main department from organizational chart
- **vi_department**: Visma integration department field
- **vi_departmentID**: Unique department identifier (N750-N830 for HQ, D006/D010 for districts)
- **vi_unitname**: Unit name within department
- **vi_unitID**: Unique unit identifier with organizational hierarchy
- **costCenter**: Cost center code matching department
- **vi_Locale**: Geographic location (Oslo for HQ, Drammen/Bergen for districts)
- **vi_StateProvince**: Organizational level (Nasjonalkontoret/Distrikt)

#### Employment Fields
- **vi_position**: Job title/position
- **vi_employeeform**: Employment type (1 Fast ansatt = Full-time employee)
- **employeeNumber**: Sequential employee number (25001-25011)
- **samAccountName**: Active Directory account name
- **managerId**: Manager's samAccountName
- **manager**: Manager's email address
- **ManagerdisplayName**: Manager's full name
- **isEmployee**: Always true for all users
- **isVolunteer**: Always false for all users
- **u_start_date**: Employment start date (DD/MM/YYYY format)
- **u_end_date**: Employment end date (empty for active employees)

#### Contact Fields
- **mobilePhone**: Norwegian mobile phone number (+47XXXXXXXX)
- **secondEmail**: Personal email address using @example.no domain
- **streetAddress**: Generic Norwegian street address
- **city**: City name (Oslo, Drammen, Bergen)
- **zipCode**: Norwegian postal code
- **state**: Organizational state (Nasjonalkontoret/Distrikt)
- **deliveryOffice**: Office location name (RK Hovedkontor, Buskerud RK, Hordaland RK)
- **division**: Full division name with code (105010-001 - RK Hovedkontor, etc.)

#### BankID Fields (Norwegian National ID)
- **bankid_birthdate**: Birth date in YY-MM-DD format
- **bankid_nnin_altsub**: Norwegian national identification number (fake)
- **bankid_altsub**: BankID alternative subject (Pass)
- **bankid_verification_timestamp**: When BankID was verified
- **bankid_user_verified**: Whether user is BankID verified (true)
- **bankid_sub**: BankID subject identifier (UUID format)
- **bankid_firstname**: First name from BankID
- **bankid_lastname**: Last name from BankID

#### System Integration Fields
- **AgressoDomainUser**: Agresso system domain user (Z94\\samAccountName)
- **RelationNumber**: Relation number (same as samAccountName)
- **Azure_lastNonInteractiveSignInDateTime**: Last Azure sign-in timestamp
- **ServiceNowManagerIdExternalID**: ServiceNow manager external ID
- **extensionAttribute7**: Extension attribute (UUID format)
- **u_crm_guid**: CRM system GUID (UUID format)

### Data Anonymization Strategy

#### Personal Information
- **Names**: Generic Norwegian names (Ola Nordmann, Kari Hansen, etc.)
- **Emails**: @urbalurba.no for work, @example.no for personal
- **Phone Numbers**: Norwegian format but fake numbers
- **Addresses**: Generic Norwegian addresses
- **BankID Data**: Valid Norwegian format but invalid numbers

#### Organizational Data
- **Department Names**: Real Red Cross department names (not sensitive)
- **Cost Centers**: Realistic codes but generic
- **Employee IDs**: Sequential numbers starting from 25001
- **Manager Relationships**: Realistic hierarchy for testing

---

## Organizational Structure

### Manager Relationships
- **ok1** (Ola Nordmann) is the manager for all other users
- All users report to ok1 via managerId and manager fields
- This creates a realistic organizational hierarchy for testing

### Department Structure
- **HQ Departments**: 9 departments covering all major Red Cross functions
- **District Offices**: 2 districts representing regional operations
- **Cost Centers**: Unique codes for each department/unit
- **Geographic Distribution**: Oslo (HQ), Drammen (Buskerud), Bergen (Hordaland)

### Group Assignment Logic
- **HQ Group**: Users with `state` or `vi_StateProvince` = "Nasjonalkontoret"
- **Distrikt Group**: Users with `state` or `vi_StateProvince` = "Distrikt"
- **Alternative Logic**: Infer from `vi_departmentID` prefix: `N...` → `HQ`, `D...` → `Distrikt`

---

## Blueprint Implementation

### Blueprint Structure

The Authentik blueprint follows this structure:

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
    # yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
    version: 1
    metadata:
      name: "Complete Okta-Compatible Test Users - Red Cross Development Environment"
      labels:
        blueprints.goauthentik.io/instantiate: "true"
    
    context: {}
    
    entries:
      # Groups first
      - model: authentik_core.group
        state: present
        identifiers:
          name: "HQ"
        attrs:
          name: "HQ"
          is_superuser: false
          attributes:
            type: "org_group"
            scope: "hq"

      - model: authentik_core.group
        state: present
        identifiers:
          name: "Distrikt"
        attrs:
          name: "Distrikt"
          is_superuser: false
          attributes:
            type: "org_group"
            scope: "district"

      # User entries go here
```

### Field Mapping Rules

#### Core Authentik Fields (Direct Mapping)
- `username` → `username`
- `email` → `email`
- `name` → `name`
- `password` → `password` (always "Password123")
- `is_active` → `is_active` (always true)

#### Custom Attributes (All Other Fields)
All other fields from the specification go into the `attributes` section:
- `department` → `attributes.department`
- `vi_department` → `attributes.vi_department`
- `employeeNumber` → `attributes.employeeNumber`
- `samAccountName` → `attributes.samAccountName`
- `managerId` → `attributes.managerId`
- `manager` → `attributes.manager`
- `ManagerdisplayName` → `attributes.ManagerdisplayName`
- `isEmployee` → `attributes.isEmployee`
- `isVolunteer` → `attributes.isVolunteer`
- `u_start_date` → `attributes.u_start_date`
- `u_end_date` → `attributes.u_end_date`
- `mobilePhone` → `attributes.mobilePhone`
- `secondEmail` → `attributes.secondEmail`
- `bankid_birthdate` → `attributes.bankid_birthdate`
- `bankid_nnin_altsub` → `attributes.bankid_nnin_altsub`
- `bankid_altsub` → `attributes.bankid_altsub`
- `bankid_verification_timestamp` → `attributes.bankid_verification_timestamp`
- `bankid_user_verified` → `attributes.bankid_user_verified`
- `bankid_sub` → `attributes.bankid_sub`
- `bankid_firstname` → `attributes.bankid_firstname`
- `bankid_lastname` → `attributes.bankid_lastname`
- `AgressoDomainUser` → `attributes.AgressoDomainUser`
- `RelationNumber` → `attributes.RelationNumber`
- `Azure_lastNonInteractiveSignInDateTime` → `attributes.Azure_lastNonInteractiveSignInDateTime`
- `ServiceNowManagerIdExternalID` → `attributes.ServiceNowManagerIdExternalID`
- `extensionAttribute7` → `attributes.extensionAttribute7`
- `u_crm_guid` → `attributes.u_crm_guid`
- `streetAddress` → `attributes.streetAddress`
- `city` → `attributes.city`
- `zipCode` → `attributes.zipCode`
- `state` → `attributes.state`
- `deliveryOffice` → `attributes.deliveryOffice`
- `division` → `attributes.division`
- `title` → `attributes.title`
- `vi_employeeform` → `attributes.vi_employeeform`
- `vi_departmentID` → `attributes.vi_departmentID`
- `vi_unitname` → `attributes.vi_unitname`
- `vi_unitID` → `attributes.vi_unitID`
- `costCenter` → `attributes.costCenter`
- `vi_Locale` → `attributes.vi_Locale`
- `vi_StateProvince` → `attributes.vi_StateProvince`
- `vi_position` → `attributes.vi_position`

### Complete User Entry Example

Here's a complete example for user `ok1`:

```yaml
- model: authentik_core.user
  state: present
  identifiers:
    username: "ok1"
  attrs:
    username: "ok1"
    name: "Ola Nordmann"
    email: "ok1@urbalurba.no"
    password: "Password123"
    is_active: true
    attributes:
      department: "Økonomi og administrasjon"
      vi_department: "Økonomi og administrasjon"
      vi_departmentID: "N750"
      vi_unitname: "Økonomi og administrasjon"
      vi_unitID: "#5421000#N750#N750#"
      costCenter: "N750"
      vi_Locale: "Oslo"
      vi_StateProvince: "Nasjonalkontoret"
      vi_position: "Økonomi- og administrasjonsmedarbeider"
      vi_employeeform: "1 Fast ansatt"
      employeeNumber: "25001"
      samAccountName: "105010OK1"
      managerId: "105010MGR1"
      manager: "manager1@urbalurba.no"
      ManagerdisplayName: "Manager Person"
      isEmployee: "true"
      isVolunteer: "false"
      u_start_date: "01/01/2020"
      u_end_date: ""
      mobilePhone: "+4790012345"
      secondEmail: "ola.nordmann@example.no"
      bankid_birthdate: "80-01-15"
      bankid_nnin_altsub: "15018012345"
      bankid_altsub: "Pass"
      bankid_verification_timestamp: "2020-01-01T09:00:00"
      bankid_user_verified: "true"
      bankid_sub: "12345678-1234-1234-1234-123456789012"
      bankid_firstname: "Ola"
      bankid_lastname: "Nordmann"
      AgressoDomainUser: "Z94\\105010OK1"
      RelationNumber: "105010OK1"
      Azure_lastNonInteractiveSignInDateTime: "2024-01-15T08:30:00Z"
      ServiceNowManagerIdExternalID: "d1b50bf41ba56690825da711604bcbf2"
      extensionAttribute7: "5207a9ec-a6bf-ec11-8117-001dd8b74416"
      u_crm_guid: "bb0a469d-905c-ef11-bfe3-0022489bed2b"
      streetAddress: "Storgata 1"
      city: "Oslo"
      zipCode: "0155"
      state: "Nasjonalkontoret"
      deliveryOffice: "RK Hovedkontor"
      division: "105010-001 - RK Hovedkontor"
      title: "Økonomi- og administrasjonsmedarbeider"
    groups:
      - !Find [authentik_core.group, [name, "HQ"]]
```

### Data Type Handling

#### String Values
Most fields are strings and should be quoted:
```yaml
attributes:
  department: "Økonomi og administrasjon"
  employeeNumber: "25001"
  isEmployee: "true"
```

#### Boolean Values
Boolean fields should be strings in Authentik:
```yaml
attributes:
  isEmployee: "true"
  isVolunteer: "false"
  bankid_user_verified: "true"
```

#### Empty Values
For empty fields, use empty strings:
```yaml
attributes:
  u_end_date: ""
```

---

## Deployment Guide

### Prerequisites

1. **Authentik namespace must exist**
2. **Blueprint ConfigMaps must be applied BEFORE deploying Authentik with Helm**
3. **Proper labels must be set for automatic discovery**
4. **Blueprint names must be listed in Helm values** under `blueprints.configMaps`

### Helm Configuration

Add the following to your Authentik Helm values file:

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
kubectl apply -f manifests/074-authentik-users-groups-blueprint.yaml

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

---

## Testing and Validation

### Validation Checklist

Before finalizing the blueprint, verify:
- [ ] All 11 users are included
- [ ] All fields from specification are mapped
- [ ] YAML syntax is valid
- [ ] Authentik blueprint format is correct
- [ ] All string values are properly quoted
- [ ] Boolean values are strings ("true"/"false")
- [ ] Empty fields use empty strings ("")
- [ ] Metadata and labels are correct
- [ ] Blueprint instantiation label is present

### Testing the Blueprint

After creating the blueprint:

1. **Apply to cluster**: `kubectl apply -f manifests/074-authentik-users-groups-blueprint.yaml`
2. **Restart Authentik** (to pick up changes immediately): `kubectl rollout restart deployment/authentik-server -n authentik`
3. **Check Authentik**: Verify users appear in Authentik admin interface
4. **Test authentication**: Try logging in with test credentials
5. **Verify fields**: Check that all custom attributes are present
6. **Test applications**: Verify integration with OpenWebUI and other apps

**Note**: Authentik automatically detects blueprint changes within 60 minutes, but restarting ensures immediate application of changes.

### Usage Notes

#### For Developers
- All users have password "Password123" for easy testing
- Users cover all major organizational scenarios
- Field values are realistic but anonymous
- Easy to modify for specific test scenarios

#### For Testing
- **Authentication**: All users can log in with their credentials
- **Authorization**: Manager relationships can be tested
- **Integration**: All Okta fields are present for app testing
- **Edge Cases**: Some fields are empty to test null handling

#### For Maintenance
- Users are created once when Authentik starts
- No updates needed after initial deployment
- Easy to add more users following the same pattern
- Clear documentation for future modifications

---

## Maintenance and Updates

### Adding New Users

1. Add user to specification table
2. Follow conversion process for new user
3. Add user entry to blueprint
4. Reapply blueprint to cluster

### Modifying Existing Users

1. Update user data in specification
2. Regenerate user entry in blueprint
3. Reapply blueprint to cluster

### Field Changes

1. Update field mapping rules if needed
2. Regenerate entire blueprint
3. Reapply blueprint to cluster

### Blueprint Updates and Redeployment

When updating blueprints:

```bash
# Update blueprint ConfigMaps
kubectl apply -f manifests/074-authentik-users-groups-blueprint.yaml

# Authentik automatically detects changes (within 60 minutes)
# Or force immediate reapplication:
kubectl rollout restart deployment/authentik-server -n authentik
```

**Note**: New blueprints require updating Helm values and redeploying Authentik, but existing blueprint changes are automatically detected.

---

## Implementation Notes

This specification will be used to create the Authentik blueprint file `manifests/074-authentik-users-groups-blueprint.yaml` which will:

1. **Create all 11 users** with complete field mappings
2. **Set up realistic organizational relationships** with manager hierarchies
3. **Provide comprehensive test data** for development
4. **Maintain data anonymity** while preserving structure
5. **Support all applications** that depend on Okta field structure

The blueprint ensures that the user specification is accurately converted into a functional Authentik configuration that provides comprehensive test data for development environments. The structured approach guarantees consistency and completeness while maintaining the flexibility to modify and extend the test data as needed.

---

## Resources

- [Authentik Blueprints Manual](doc/package-auth-authentik-blueprints-syntax.md)
- [Okta Fields Reference](terchris/okta/okta-fields.md)
- [User Table Specification](terchris/okta/user-table.md)
- [Blueprint Conversion Guide](terchris/okta/howto-convert-userdatatblueprint.md)
- [Official Authentik Blueprint Documentation](https://docs.goauthentik.io/customize/blueprints/)
- [Blueprint Schema](https://goauthentik.io/blueprints/schema.json)

---

*Last updated: January 2025*