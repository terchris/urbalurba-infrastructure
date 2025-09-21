# Urbalurba Infrastructure Rules Guide

**File**: `doc/rules-readme.md`
**Purpose**: Central entry point for all infrastructure rules and standards
**Target Audience**: Developers, DevOps engineers, and anyone working with the Urbalurba platform
**Last Updated**: September 21, 2024

## 📋 **Overview**

This is the central starting point for understanding all rules, standards, and best practices when working with the Urbalurba infrastructure platform. The rules are organized into specialized guides covering different aspects of the platform.

## 🚀 **Rule Categories**

### **Infrastructure Provisioning Rules**
**📖 [Provisioning Rules Guide](rules-provisioning.md)**

Comprehensive rules for deploying and managing infrastructure on Kubernetes using the Urbalurba platform patterns:

- **Shell Script + Ansible Patterns**: Separation of orchestration and implementation
- **Cluster Testing Standards**: kubectl run patterns for reliable service verification
- **Progress Feedback Requirements**: User experience during long-running operations
- **Task Organization**: Sequential numbering and proper structure
- **Error Handling**: Quiet success, verbose failure patterns
- **Helm Repository Management**: Consistent chart deployment practices

**When to use**: Infrastructure deployment, service provisioning, cluster setup automation

---

### **Ingress and Networking Rules**
**🚦 [Ingress Rules Guide](rules-ingress-traefik.md)**

Detailed standards for configuring ingress and networking using Traefik in the Kubernetes cluster:

- **Traefik IngressRoute Standards**: CRD usage patterns and API versions
- **Multi-Domain Routing**: HostRegexp patterns for flexible domain handling
- **Authentication Integration**: Authentik middleware configuration
- **DNS Architecture**: Dual-context routing for localhost and external domains
- **Security Patterns**: CSP middleware and forward auth configurations

**When to use**: Service exposure, domain routing, authentication setup, external access

---

### **Git Workflow and Development Rules**
**🔀 [Git Workflow Rules Guide](rules-git-workflow.md)**

Professional Git workflow standards for maintaining code quality and enabling collaboration:

- **Feature Branch Workflow**: Branch strategy and naming conventions
- **Pull Request Requirements**: Mandatory PR process with detailed descriptions
- **Code Review Standards**: Quality criteria and review processes
- **Commit Message Standards**: Clear, descriptive commit practices
- **Branch Management**: Creation, merging, and cleanup procedures
- **Emergency Procedures**: Hotfix and rollback processes

**When to use**: All code contributions, feature development, bug fixes, documentation updates

---

## 🎯 **Quick Reference**

### **For New Developers**
1. **Start with**: [Git Workflow Rules](rules-git-workflow.md) - Learn development workflow and collaboration
2. **Then read**: [Provisioning Rules](rules-provisioning.md) - Learn infrastructure deployment patterns
3. **Finally**: [Ingress Rules](rules-ingress-traefik.md) - Understand service exposure

### **For Development Work**
- **Making code changes**: Follow [Git Workflow Rules](rules-git-workflow.md)
- **Deploying services**: Follow [Provisioning Rules](rules-provisioning.md)
- **Exposing services**: Follow [Ingress Rules](rules-ingress-traefik.md)

### **For Troubleshooting**
- **Deployment issues**: Check Rule 3 in [Provisioning Rules](rules-provisioning.md) for cluster testing patterns
- **Access issues**: Check DNS resolution in [Ingress Rules](rules-ingress-traefik.md)

## 🔧 **Rule Enforcement**

### **Automated Validation**
- CI/CD pipelines should validate compliance with these rules
- Use the patterns documented in each guide as templates

### **Manual Review**
- All pull requests must demonstrate rule compliance
- Peer reviews should verify adherence to documented patterns
- No exceptions without documented justification

## 📚 **Related Documentation**

- **🌐 Networking Overview**: `doc/networking-readme.md` - High-level cluster networking
- **🏗️ Infrastructure Guide**: `doc/infrastructure-readme.md` - Overall platform architecture
- **🤖 AI Environment**: `doc/package-ai-environment-management.md` - AI-specific patterns

## 🆕 **Contributing to Rules**

### **When to Add New Rules**
- Recurring anti-patterns are discovered
- New deployment patterns are established
- Infrastructure standards evolve

### **Rule Documentation Standards**
- Each rule must include examples (both ✅ correct and ❌ incorrect)
- Background explanation of why the rule exists
- Clear enforcement criteria
- Links to working examples in the codebase

### **Update Process**
1. Propose rule changes via pull request
2. Update relevant rule guide ([Provisioning](rules-provisioning.md) or [Ingress](rules-ingress-traefik.md))
3. Update this central guide if categories change
4. Ensure all existing code complies with new rules

---

**💡 Remember**: These rules exist to ensure reliable, maintainable, and scalable infrastructure. They represent lessons learned from real deployment challenges and should be followed consistently across all Urbalurba infrastructure work.