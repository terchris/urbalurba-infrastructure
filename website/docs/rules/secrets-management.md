# Secrets Management Rules and Standards

**File**: `docs/rules-secrets-management.md`
**Purpose**: Define mandatory rules and patterns for secrets management in the Urbalurba Infrastructure
**Target Audience**: Developers, DevOps engineers, and LLMs working with secrets and configuration
**Last Updated**: September 21, 2025

## 📋 **Overview**

This document establishes mandatory rules for managing secrets using the modular secrets management system. These rules ensure security, maintainability, and prevent accidental exposure of sensitive information.

## 🔒 **Core Security Architecture**

### **Rule 1: Never Commit Secrets Pattern**
All secrets handling MUST follow the **Template + Gitignore** pattern:

```
secrets-templates/     →  secrets-config/     →  kubernetes-secrets.yml
  ↑ Git tracked           ↑ Gitignored           ↑ Gitignored
  ↑ ${VARIABLES}          ↑ Actual secrets       ↑ Final YAML
```

#### **✅ Safe Operations**:
- Edit files in `secrets-templates/` with `${VARIABLE}` placeholders only
- Edit files in `secrets-config/` for actual secret values
- Use `./create-kubernetes-secrets.sh` to generate final secrets
- Backup secrets to `terchris/` folder if needed

#### **❌ Forbidden Operations**:
- **NEVER** put actual secrets in `secrets-templates/`
- **NEVER** commit files from `secrets-config/` or `secrets-generated/`
- **NEVER** create copies of `kubernetes-secrets.yml` in git-tracked areas
- **NEVER** store secrets in documentation, comments, or README files

### **Rule 2: Variable Substitution Pattern**
ALL secrets MUST use centralized variable management:

#### **✅ Correct Pattern**:
```bash
# In secrets-config/00-common-values.env.template
DEFAULT_DATABASE_PASSWORD=YourSecurePassword123
DEFAULT_ADMIN_EMAIL=admin@yourcompany.com

# In secrets-config/00-master-secrets.yml.template
PGPASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
AUTHENTIK_BOOTSTRAP_EMAIL: "${DEFAULT_ADMIN_EMAIL}"
```

#### **❌ Anti-Pattern**:
```yaml
# DON'T: Hard-code different passwords for each service
PGPASSWORD: "postgres-specific-password"
MYSQL_ROOT_PASSWORD: "mysql-different-password"
REDIS_PASSWORD: "redis-another-password"
```

**Why**: Centralized variables enable password rotation across all services simultaneously.

### **Rule 3: Modular System Usage Pattern**
The generation script MUST be used correctly:

#### **✅ Correct Workflow**:
```bash
# 1. Edit your configuration
nano secrets-config/00-common-values.env.template
nano secrets-config/00-master-secrets.yml.template

# 2. Generate secrets
./create-kubernetes-secrets.sh

# 3. Validate before applying
kubectl apply --dry-run=client -f kubernetes/kubernetes-secrets.yml

# 4. Deploy to cluster
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

#### **❌ Anti-Pattern**:
```bash
# DON'T: Edit generated files directly
nano kubernetes/kubernetes-secrets.yml

# DON'T: Skip validation
kubectl apply -f kubernetes/kubernetes-secrets.yml  # Without dry-run

# DON'T: Edit base templates with secrets
nano secrets-templates/00-master-secrets.yml.template  # Putting actual values
```

## 🛡️ **Security Rules**

### **Rule 4: Git Safety Verification**
Before ANY git operation, MUST verify no secrets are staged:

#### **✅ Required Verification Commands**:
```bash
# 1. Check what's staged for commit
git status

# 2. Verify gitignore is working
git check-ignore secrets-config/
git check-ignore secrets-generated/

# 3. Check for secret patterns in staged files
git diff --cached | grep -i "password\|secret\|key"
```

#### **❌ Forbidden Git Operations**:
- Committing without running verification commands
- Adding `secrets-config/` or `secrets-generated/` to git
- Using `git add .` without checking what's included
- Creating documentation that contains actual secret values

### **Rule 5: Service Integration Pattern**
When adding secrets for new services, follow the established pattern:

#### **✅ Correct Service Integration**:
```yaml
# 1. Add variables to common values (if reusable)
MYSERVICE_DATABASE_PASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
MYSERVICE_ADMIN_EMAIL: "${DEFAULT_ADMIN_EMAIL}"

# 2. Add service-specific secrets (if unique)
MYSERVICE_API_KEY: "your-service-specific-key"
MYSERVICE_JWT_SECRET: "your-jwt-secret"

# 3. Use proper namespace structure
---
apiVersion: v1
kind: Secret
metadata:
  name: urbalurba-secrets
  namespace: myservice
type: Opaque
stringData:
  MYSERVICE_DATABASE_PASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
  MYSERVICE_API_KEY: "${MYSERVICE_API_KEY}"
```

#### **❌ Anti-Pattern**:
```yaml
# DON'T: Hard-code secrets in templates
stringData:
  MYSERVICE_DATABASE_PASSWORD: "hardcoded-password"

# DON'T: Skip namespace organization
metadata:
  name: myservice-specific-secret  # Should use urbalurba-secrets
  namespace: default              # Should use service namespace
```

### **Rule 6: No Helm Chart Defaults for Security Values**
NEVER use Helm chart default values for security-sensitive parameters:

#### **✅ Correct Pattern: Override All Security Defaults**
```yaml
# In Ansible playbook deployment
helm upgrade --install {{ service_name }} bitnami/rabbitmq \
  --set auth.username={{ rabbitmq_username_fact | quote }} \
  --set auth.password={{ rabbitmq_password_fact | quote }} \
  --set auth.erlangCookie={{ rabbitmq_erlang_cookie_fact | quote }}
```

```yaml
# In secrets configuration
RABBITMQ_USERNAME: "${DEFAULT_ADMIN_USERNAME}"
RABBITMQ_PASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
RABBITMQ_ERLANG_COOKIE: "${RABBITMQ_ERLANG_COOKIE}"
```

#### **❌ Anti-Pattern: Using Chart Defaults**
```yaml
# DON'T: Let Helm chart use default credentials
auth:
  username: user          # Bitnami default - predictable!
  password: bitnami       # Chart default - insecure!

# DON'T: Only override passwords but leave usernames as defaults
auth:
  username: user          # Still using chart default
  password: "${SECURE_PASSWORD}"  # Good, but incomplete
```

#### **Security-Sensitive Helm Parameters to Always Override**
- **Usernames**: `auth.username`, `rootUser.username`, `adminUser`
- **Passwords**: `auth.password`, `rootPassword`, `adminPassword`
- **API Keys**: `apiKey`, `secretKey`, `accessKey`
- **Tokens**: `authToken`, `jwtSecret`, `sessionSecret`
- **Cookies**: `erlangCookie`, `sessionCookie`
- **Database URLs**: Connection strings with embedded credentials

#### **Why This Matters**
- ✅ **Predictable defaults** are security vulnerabilities
- ✅ **Chart documentation** publishes default values publicly
- ✅ **Centralized management** enables credential rotation
- ✅ **Consistent security** across all services

**Example: Common Bitnami Chart Defaults to Avoid**
```bash
# PostgreSQL defaults
auth.postgresPassword: "postgres"
auth.username: "postgres"

# Redis defaults
auth.password: "bitnami"

# RabbitMQ defaults
auth.username: "user"
auth.password: "bitnami"

# MongoDB defaults
auth.rootPassword: "root"
auth.username: "root"
```

**All of these MUST be overridden with values from `urbalurba-secrets`.**

### **Rule 7: ConfigMap Management Pattern**
ConfigMaps follow the same template pattern as secrets but for **non-sensitive configuration data**:

#### **✅ ConfigMap Directory Structure**:
```bash
secrets-templates/
├── configmaps/
│   ├── [namespace]/
│   │   ├── [category]/
│   │   │   └── [config-name].[ext].template
│   │   └── dashboards/     # Special: Auto-labeled
│   │       └── my-dashboard.json.template
```

#### **✅ Auto-Discovery Pattern**:
- **Templates**: Place files in `secrets-templates/configmaps/[namespace]/[category]/`
- **Processing**: Any `*.template` file is automatically discovered
- **Variables**: Use same `${VARIABLE}` pattern as secrets
- **Labeling**: Automatic based on directory conventions

#### **✅ Directory Conventions & Auto-Labeling**:
```yaml
# dashboards/ → Label: grafana_dashboard: "1"
configmaps/monitoring/dashboards/*.json.template

# nginx/ → Label: app: nginx
configmaps/[namespace]/nginx/*.conf.template

# otel/ → Label: app.kubernetes.io/name: otel-collector
configmaps/monitoring/otel/*.yaml.template

# Default → Label: managed-by: secrets-pipeline
configmaps/[namespace]/configs/*.yaml.template
```

#### **✅ Developer Workflow**:
```bash
# 1. Add new ConfigMap template
echo 'server: ${MY_SERVER}' > secrets-templates/configmaps/myapp/configs/app.conf.template

# 2. Run generation (discovers automatically)
./create-kubernetes-secrets.sh

# 3. Deploy everything together
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

#### **✅ Customization Pattern**:
```bash
# Templates copied to secrets-config/ on first run
secrets-config/configmaps/monitoring/dashboards/my-dashboard.json.template

# Edit for customization (variables substituted, file preserved)
nano secrets-config/configmaps/monitoring/configs/custom.yaml.template

# Regenerate (preserves edits, updates variables)
./create-kubernetes-secrets.sh
```

#### **❌ ConfigMap Anti-Patterns**:
- **NEVER** put sensitive data in ConfigMaps (use Secrets instead)
- **NEVER** create ConfigMaps outside the pipeline (use template system)
- **NEVER** hardcode values (use `${VARIABLES}` for dynamic data)
- **NEVER** edit generated YAML directly (edit templates instead)

#### **ConfigMap vs Secret Decision Matrix**:
```bash
# ✅ ConfigMaps (Non-sensitive)
- Application configuration files
- Dashboard definitions (JSON/YAML)
- Service discovery settings
- Public certificates
- Database connection hosts/ports

# ❌ Secrets (Sensitive)
- Passwords, API keys, tokens
- Private certificates/keys
- Database connection strings with passwords
- OAuth client secrets
```

## 🔧 **Operational Rules**

### **Rule 8: Testing and Validation**
ALL secret changes MUST be validated before deployment:

#### **✅ Required Testing Steps**:
```bash
# 1. Generate and validate YAML syntax
./create-kubernetes-secrets.sh
kubectl apply --dry-run=client -f kubernetes/kubernetes-secrets.yml

# 2. Check for variable substitution errors
grep '${' kubernetes/kubernetes-secrets.yml  # Should return no results

# 3. Verify critical services have required secrets
grep -c "PGPASSWORD\|REDIS_PASSWORD\|AUTHENTIK_SECRET_KEY" kubernetes/kubernetes-secrets.yml
```

#### **❌ Skip Testing**:
- Deploying without YAML validation
- Not checking for unresolved variables
- Missing verification that critical secrets are present

### **Rule 9: Backup and Recovery Pattern**
Secret backups MUST follow secure patterns:

#### **✅ Correct Backup**:
```bash
# Backup to gitignored terchris folder
cp kubernetes/kubernetes-secrets.yml terchris/secrets-backup/backup-$(date +%Y%m%d).yml

# Backup configuration (not generated files)
cp -r secrets-config/ terchris/config-backup-$(date +%Y%m%d)/
```

#### **❌ Insecure Backup**:
```bash
# DON'T: Backup to git-tracked areas
cp kubernetes/kubernetes-secrets.yml docs/backup.yml
cp secrets-config/00-common-values.env.template examples/
```

## 🚨 **Emergency Procedures**

### **Rule 8: Secret Rotation Process**
When rotating secrets, follow this sequence:

#### **✅ Safe Rotation Process**:
```bash
# 1. Update central variables first
nano secrets-config/00-common-values.env.template
# Change DEFAULT_DATABASE_PASSWORD, DEFAULT_ADMIN_PASSWORD, etc.

# 2. Update service-specific secrets if needed
nano secrets-config/00-master-secrets.yml.template

# 3. Generate and validate
./create-kubernetes-secrets.sh
kubectl apply --dry-run=client -f kubernetes/kubernetes-secrets.yml

# 4. Deploy during maintenance window
kubectl apply -f kubernetes/kubernetes-secrets.yml

# 5. Restart affected services
kubectl rollout restart deployment/service-name -n namespace
```

### **Rule 9: Incident Response**
If secrets are accidentally exposed:

#### **✅ Immediate Response**:
```bash
# 1. Remove from git immediately
git reset HEAD~1  # If not pushed
git filter-branch  # If pushed (contact team)

# 2. Rotate ALL exposed secrets
# Update secrets-config/00-common-values.env.template with new values

# 3. Audit access logs
# Check who had access to exposed secrets

# 4. Update documentation
# Record incident and lessons learned
```

## 📚 **Integration Rules**

### **Rule 10: Cross-System Dependencies**
Secrets management integrates with other systems:

#### **✅ Required Coordination**:
- **Provisioning**: Secrets MUST be generated before running deployment scripts
- **Ingress**: Domain names in secrets MUST match ingress configurations
- **Git Workflow**: Secret changes MUST go through pull request process
- **Monitoring**: Failed secret deployments MUST trigger alerts

#### **✅ Verification Commands**:
```bash
# Verify domain consistency with ingress
grep -E "BASE_DOMAIN_|TAILSCALE_DOMAIN|CLOUDFLARE" secrets-config/00-common-values.env.template

# Verify secrets exist before deployment
kubectl get secret urbalurba-secrets -n default
kubectl get secret urbalurba-secrets -n ai
kubectl get secret urbalurba-secrets -n authentik
```

## 🎯 **Enforcement**

### **Automated Validation**
These rules SHOULD be enforced by:
- Pre-commit hooks checking for secret patterns
- CI/CD pipeline validation of YAML syntax
- Automated testing of secret generation process

### **Manual Review Requirements**
ALL secret changes MUST be reviewed for:
- Compliance with variable substitution patterns
- Proper gitignore coverage
- Security best practices
- Integration with existing services

## 🔄 **Template Update Rules**

### **Rule 11: User Config Override Pattern**
When updating base templates, you MUST also update the user's config for immediate effect:

#### **✅ Correct Workflow for Template Updates**:
```bash
# 1. Update base template (for team sharing)
nano secrets-templates/00-master-secrets.yml.template
git add secrets-templates/
git commit -m "Add new secret template"

# 2. Update user's config (for immediate use)
nano secrets-config/00-master-secrets.yml.template
./create-kubernetes-secrets.sh

# 3. Deploy updated secrets
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

#### **❌ Anti-Pattern**:
```bash
# DON'T: Only update base templates
nano secrets-templates/00-master-secrets.yml.template
./create-kubernetes-secrets.sh  # Will use old user config!
```

#### **Why This Rule Exists**:
The generation script prioritizes `secrets-config/` over `secrets-templates/` to enable user customization. Base templates are for team sharing, but user configs are for immediate use.

#### **Verification Commands**:
```bash
# Check if user config exists and is up to date
ls -la secrets-config/00-master-secrets.yml.template

# Compare with base template
diff secrets-templates/00-master-secrets.yml.template secrets-config/00-master-secrets.yml.template

# Verify generation uses user config
./create-kubernetes-secrets.sh
grep "Your new secret" kubernetes/kubernetes-secrets.yml
```

---

**💡 Remember**: These rules exist to prevent security breaches and maintain system reliability. They represent lessons learned from real incidents and should be followed consistently across all Urbalurba infrastructure work.