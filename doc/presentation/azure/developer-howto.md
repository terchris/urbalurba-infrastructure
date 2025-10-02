# Developer HOWTO

## Slide: Developer Guidelines

**Core Requirements:**
- **Shared Resources** - Use centralized services, not separate instances
- **Private Networking** - VNet integration only, no public IPs
- **Security First** - Managed Identities, Key Vault, RBAC
- **Governance** - Tag resources, follow naming, use Bicep

**Development Process:**
- **Trunk-Based Git** - Short feature branches, continuous integration
- **3 Environments** - Dev (manual), Test (auto), Prod (tag-based)
- **APIM** - Separate pipeline, manual deployment

**Logging Standards:**
- **Structured JSON** - Machine-readable format required
- **System ID** - Unique identifier per integration (INT0001001)
- **Correlation IDs** - Enable cross-service tracing

---

## Speaker Notes

**Opening (30 seconds)**
"Our platform has clear standards that ensure every integration is secure and maintainable. These aren't restrictions - they're what make us reliable."

**Key Points (1 minute)**
"Every developer must:
- Use shared services instead of creating separate instances
- Follow security standards with private networking and managed identities
- Use structured logging with system IDs for easy troubleshooting
- Follow our trunk-based development process with clear deployment rules"

**Closing (30 seconds)**
"When everyone follows the same patterns, we move faster and solve problems quicker. These standards are our competitive advantage."
