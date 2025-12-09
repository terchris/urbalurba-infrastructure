# Documentation Creation Rules and Standards

**File**: `docs/rules-howtodoc.md`
**Purpose**: Define mandatory rules and patterns for creating documentation in the Urbalurba Infrastructure
**Target Audience**: Developers, technical writers, and LLMs creating documentation
**Last Updated**: September 23, 2025

## 📋 **Overview**

This document establishes mandatory rules for creating and maintaining documentation in the `docs/` folder. These rules ensure consistency, discoverability, and maintainability across all documentation types in the Urbalurba infrastructure.

## 🏗️ **Core Documentation Architecture**

### **Rule 1: Three-Tier Naming Convention**
ALL documentation files MUST follow the hierarchical naming pattern:

```
<larger-grouping>-<focus-grouping>-<service>.md
```

#### **Mandatory Naming Patterns**:
- **Service Documentation**: `package-databases-postgresql.md`
- **Index Files**: `package-databases-readme.md`
- **Technical Guides**: `rules-ingress-traefik.md`
- **Overview Documents**: `overview-system-architecture.md`

#### **✅ Approved Larger Groupings**:
- `package` - Service and application deployments
- `overview` - High-level guides and architectural overviews
- `rules` - Standards, patterns, and mandatory procedures
- `hosts` - Host system configuration and setup
- `networking` - Network configuration and connectivity
- `provision` - Infrastructure provisioning and management
- `troubleshooting` - Problem diagnosis and resolution
- `secrets` - Security and secrets management

#### **✅ Approved Package Focus Groupings**:
- `ai` - Artificial Intelligence and ML services
- `auth` - Authentication and authorization systems
- `core` - Essential infrastructure services
- `databases` - Data storage and management
- `datascience` - Analytics and data processing
- `development` - Developer tools and workflows
- `management` - Administrative and monitoring tools
- `queues` - Message brokers and queuing systems
- `search` - Search and indexing services

### **Rule 2: Index File Pattern**
Every focus grouping MUST have an index file:

```
<larger-grouping>-<focus-grouping>-readme.md
```

**Purpose**: Serve as the entry point and navigation hub for all related service documentation.

#### **Required Index File Content**:
1. **Overview** of the focus grouping purpose
2. **Service listing** with status indicators
3. **Quick start** instructions
4. **Architecture** summary
5. **Cross-references** to related documentation

## 📝 **Document Structure Rules**

### **Rule 3: Standard Header Format**
ALL documentation files MUST start with this header:

```markdown
# [Service Name] - [Brief Description]

**Key Features**: Feature1 • Feature2 • Feature3 • Feature4 • Feature5 • Feature6

**File**: `docs/[filename].md`
**Purpose**: [Single sentence describing document purpose]
**Target Audience**: [Specific user groups]
**Last Updated**: [Date in format: September 23, 2025]
```

#### **Header Requirements**:
- **Title**: Clear service name with descriptive subtitle
- **Key Features**: 3-7 bullet points using • separator
- **File Path**: Exact relative path from repository root
- **Purpose**: One sentence maximum, specific and actionable
- **Target Audience**: Comma-separated list of user personas
- **Last Updated**: Date in full month format

### **Rule 4: Service Documentation Template**
Service documentation (`package-*-[service].md`) MUST follow this structure:

```markdown
# [Service Name] - [Brief Description]

**Key Features**: [List using • separator]
**File**: `docs/package-[category]-[service].md`
**Purpose**: Complete guide to [service] deployment and configuration in Urbalurba infrastructure
**Target Audience**: [Specific personas]
**Last Updated**: [Date]

## 📋 Overview
[2-3 paragraphs describing service role and capabilities]

**Key Features**:
- **Feature 1**: Description
- **Feature 2**: Description
- **Architecture Type**: Description

## 🏗️ Architecture
### **Deployment Components**
```
[ASCII diagram of service stack]
```

### **File Structure**
```
[Directory structure showing related files]
```

## 🚀 Deployment
### **Manual Deployment**
### **Prerequisites**

## ⚙️ Configuration
### **[Service] Configuration**
### **Resource Configuration**
### **Security Configuration**

## 🔍 Monitoring & Verification
### **Health Checks**
### **Service Verification**
### **[Service] Access Testing**
### **Automated Verification**

## 🛠️ Management Operations
### **[Service] Administration**
### **Service Removal**

## 🔧 Troubleshooting
### **Common Issues**

## 📋 Maintenance
### **Regular Tasks**
### **Backup Procedures**
### **Disaster Recovery**

## 🚀 Use Cases
[3-4 practical examples with code]
```

### **Rule 5: Index Documentation Template**
Index files (`*-readme.md`) MUST follow this structure:

```markdown
# [Category Name] - [Description]

**File**: `docs/[category]-readme.md`
**Purpose**: Overview of all [category] services in Urbalurba infrastructure
**Target Audience**: [User groups]
**Last Updated**: [Date]

## 📋 Overview
[Category description and purpose]

**Available [Category] Services**:
- **Service 1**: Brief description
- **Service 2**: Brief description

## [Icon] [Category] Services
### **Service Name - Primary Service** 🥇
**Status**: Active | **Port**: [port] | **Type**: [type]

[Service description paragraph]

**Key Features**:
- **Feature 1**: Description
- **Feature 2**: Description

**Documentation**: [package-category-service.md](./package-category-service.md)

## 🚀 Quick Start
[Category-wide deployment instructions]

## 🔗 Related Documentation
[Cross-references to related docs]
```

## 🎯 **Content Quality Rules**

### **Rule 6: Mandatory Metadata Fields**
Every document MUST include:

#### **Required Fields**:
- `**File**`: Exact path from repository root
- `**Purpose**`: Single sentence description
- `**Target Audience**`: Specific user personas
- `**Last Updated**`: Date in full format

#### **Service Documents Must Add**:
- `**Key Features**`: 3-7 items with • separator
- Architecture diagrams (ASCII or Mermaid)
- File structure listings
- Practical use case examples

#### **Index Documents Must Add**:
- Service status indicators (Active/Inactive/Development)
- Quick start section
- Cross-reference links

### **Rule 7: Status Indicators**
Use these standardized status indicators:

```markdown
**Status**: ✅ Active | 🔄 Development | ⏸️ Inactive | 🚫 Deprecated
```

### **Rule 8: Cross-Reference Standards**
#### **Link Format**:
```markdown
[Document Title](./filename.md)
**Documentation**: [package-category-service.md](./package-category-service.md)
```

#### **Required Cross-References**:
- Index files MUST link to all service documentation
- Service files MUST link back to index file
- Related services MUST be cross-referenced
- Prerequisites MUST link to setup documentation

## 🔧 **Technical Writing Standards**

### **Rule 9: Code and Configuration Examples**
#### **Required Elements**:
- **Command examples**: Include description comments
- **Configuration snippets**: Show context and purpose
- **File paths**: Always use absolute paths from repository root
- **Variable placeholders**: Use `[variable-name]` format

#### **Code Block Standards**:
```markdown
# Description of what this does
```bash
command --option value
```

```yaml
# Configuration section purpose
key: value
```

### **Rule 10: Emoji and Visual Indicators**
Use standardized emoji patterns:

```markdown
## 📋 Overview          # Overview sections
## 🚀 Deployment        # Getting started/deployment
## 🏗️ Architecture      # System design/structure
## ⚙️ Configuration     # Setup and config
## 🔍 Monitoring        # Verification/monitoring
## 🛠️ Management        # Operations/admin
## 🔧 Troubleshooting   # Problem solving
## 📋 Maintenance       # Ongoing tasks
## 🔗 Related           # Cross-references
```

#### **Status Indicators**:
```markdown
✅ Success/Active/Complete
🔄 In Progress/Development
⚠️ Warning/Attention Required
❌ Error/Failed/Deprecated
🎯 Target/Goal/Objective
💡 Tip/Insight/Key Point
```

## 📂 **File Organization Rules**

### **Rule 11: Directory Structure**
Files MUST be placed directly in `/doc/` folder:

```
doc/
├── README.md                           # Master index
├── overview-*.md                       # High-level guides
├── package-category-readme.md          # Category indexes
├── package-category-service.md         # Service documentation
├── rules-*.md                          # Standards and patterns
├── hosts-*.md                          # Host configuration
├── networking-*.md                     # Network setup
├── provision-*.md                      # Infrastructure management
└── troubleshooting-*.md                # Problem resolution
```

#### **Forbidden**:
- **Subdirectories**: All `.md` files must be in root `/doc/`
- **Spaces in names**: Use hyphens instead
- **Version numbers**: Use "Last Updated" metadata instead
- **Duplicate names**: Each filename must be unique

### **Rule 12: New Category Creation**
Before creating a new larger grouping:

#### **Required Justification**:
1. **Scope**: Does it warrant 3+ service documents?
2. **Distinction**: Is it clearly different from existing categories?
3. **Longevity**: Will it remain relevant long-term?
4. **User Value**: Does it improve navigation and discoverability?

#### **Creation Process**:
1. **Document proposal** with justification
2. **Create index file** first: `[grouping]-readme.md`
3. **Add to main README.md** navigation
4. **Create minimum 2 service documents**

## 🔍 **Quality Assurance Rules**

### **Rule 13: Review Requirements**
Before publishing documentation:

#### **Self-Review Checklist**:
- [ ] Header format matches Rule 3 exactly
- [ ] Structure follows appropriate template (Rule 4 or 5)
- [ ] All required metadata fields present
- [ ] Code examples tested and working
- [ ] Cross-references valid and functional
- [ ] Grammar and spelling checked
- [ ] Last Updated date is current

#### **Content Validation**:
- [ ] Commands execute successfully
- [ ] File paths exist and are correct
- [ ] Configuration examples are valid
- [ ] Screenshots/diagrams are current
- [ ] Use cases demonstrate real value

### **Rule 14: Maintenance Standards**
#### **Update Requirements**:
- **Content changes**: Update "Last Updated" date
- **Significant revisions**: Update purpose or target audience if needed
- **Broken links**: Fix within 24 hours of discovery
- **Deprecated features**: Mark clearly with status indicators

#### **Regular Reviews**:
- **Monthly**: Check for broken internal links
- **Quarterly**: Validate code examples and commands
- **Semi-annually**: Review structure and cross-references
- **Annually**: Comprehensive content audit

## 🚨 **Anti-Patterns and Violations**

### **Rule 15: Forbidden Practices**
#### **Never Do This**:
```markdown
❌ # How to setup postgres              # Unclear, no context
❌ **File**: postgres.md               # Wrong path format
❌ **Purpose**: This document...       # Verbose, not specific
❌ **Target Audience**: Everyone       # Too broad
❌ **Last Updated**: 2024              # Incomplete date format
❌ See documentation for setup         # Vague cross-reference
❌ Run this command: sudo rm -rf /     # Dangerous without context
```

#### **Always Do This**:
```markdown
✅ # PostgreSQL - Primary Database Service
✅ **File**: `docs/package-databases-postgresql.md`
✅ **Purpose**: Complete guide to PostgreSQL deployment and configuration in Urbalurba infrastructure
✅ **Target Audience**: Database administrators, developers, architects
✅ **Last Updated**: September 23, 2025
✅ **Documentation**: [PostgreSQL Setup Guide](./package-databases-postgresql.md)
✅ # Deploy PostgreSQL with authentication
   kubectl apply -f manifests/050-postgresql-config.yaml
```

## 📈 **Success Metrics**

### **Rule 16: Quality Indicators**
Documentation quality is measured by:

#### **Structure Compliance**:
- ✅ 100% header format compliance
- ✅ Template structure adherence
- ✅ Required section completeness
- ✅ Cross-reference accuracy

#### **User Value Metrics**:
- ✅ Clear, actionable instructions
- ✅ Working code examples
- ✅ Comprehensive troubleshooting
- ✅ Practical use case demonstrations

#### **Maintenance Health**:
- ✅ Current "Last Updated" dates
- ✅ No broken links
- ✅ Accurate file references
- ✅ Valid command examples

---

**💡 Key Insight**: Consistent documentation structure and naming conventions are essential for maintainability and user experience. These rules ensure that all documentation in the Urbalurba infrastructure follows predictable patterns, making it easier for users to find information and for contributors to create high-quality documentation that serves its intended audience effectively.