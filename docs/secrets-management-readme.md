# Modular Secrets Management System

**File**: `docs/secrets-management-readme.md`
**Purpose**: Complete guide to the modular, template-based secrets management system
**Target Audience**: Developers, DevOps engineers, system administrators

## 📋 **Overview**

The Urbalurba infrastructure now uses a **modular secrets management system** that:

- **Separates concerns**: Base templates (git-tracked) vs user secrets (gitignored)
- **Prevents secret leaks**: No actual secrets ever enter version control
- **Enables customization**: Users can modify their secrets without affecting others
- **Supports variables**: Central configuration with `${VARIABLE}` substitution

### **⚠️ IMPORTANT: How It Actually Works**

**The ONLY file Kubernetes uses is: `kubernetes/kubernetes-secrets.yml`**

Everything else (templates, configs, variables) exists solely to:
- Make generating this single file easier
- Prevent secrets from entering git
- Enable consistent configuration across services
- Simplify password management

**Bottom line**: All the modular system does is generate `kubernetes-secrets.yml` - that's the only file that gets deployed to your cluster.

## 🚀 **Quick Start**

### **Automatic Setup (Normal Flow)**
The `install-rancher.sh` script automatically calls `create-kubernetes-secrets.sh` during cluster build.
You don't need to run anything manually unless you're updating secrets.

### **Updating/Customizing Secrets**
Only run these commands when you need to change secret values:

```bash
# 1. Edit your actual secrets (gitignored)
cd topsecret/
nano secrets-config/00-common-values.env.template
nano secrets-config/00-master-secrets.yml.template

# 2. Regenerate kubernetes-secrets.yml with your new values
./create-kubernetes-secrets.sh

# 3. Apply the updated secrets to your cluster
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

**Note**: The script automatically:
- Creates `secrets-config/` from templates on first run (if missing)
- Loads your custom values
- Generates `kubernetes/kubernetes-secrets.yml`
- Validates YAML syntax with kubectl

## 📁 **File Structure**

```
topsecret/
├── create-kubernetes-secrets.sh           # ✅ Generation script (git tracked)
├── secrets-templates/                     # ✅ Base templates (git tracked)
│   ├── 00-common-values.env.template      # ✅ Variable definitions
│   ├── 00-master-secrets.yml.template     # ✅ Master secret template
│   ├── 01-core-secrets.yml.template       # ✅ Core services template
│   ├── 07-ai-secrets.yml.template         # ✅ AI services template
│   └── ... (other base templates)
├── secrets-config/                        # ❌ Your secrets (gitignored)
│   ├── 00-common-values.env.template      # ❌ Your actual values
│   ├── 00-master-secrets.yml.template     # ❌ Your customized template
│   └── ... (your customized templates)
├── secrets-generated/                     # ❌ Generated files (gitignored)
│   └── 00-common-values.env               # ❌ Processed values
└── kubernetes/
    └── kubernetes-secrets.yml             # ❌ THE ONLY FILE KUBERNETES USES!
                                           # ❌ Everything else exists to generate THIS file
```

### **🔒 Security Model**

| Directory | Git Tracked | Contains | Purpose |
|-----------|-------------|----------|---------|
| `secrets-templates/` | ✅ Yes | `${VARIABLE}` placeholders | Base templates for team |
| `secrets-config/` | ❌ No | Actual secrets | User's private configuration |
| `secrets-generated/` | ❌ No | Resolved values | Processing workspace |
| `kubernetes/` | ❌ No | Final YAML | Ready for kubectl apply |

## 🔧 **Key Features**

### **1. Variable Substitution**
Central configuration in `secrets-config/00-common-values.env.template`:

```bash
# Change this once, affects all database passwords
DEFAULT_DATABASE_PASSWORD=YourSecurePassword123

# Change this once, affects all admin credentials
DEFAULT_ADMIN_EMAIL=admin@yourcompany.com
DEFAULT_ADMIN_PASSWORD=YourAdminPassword456
```

Templates use variables like:
```yaml
PGPASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
AUTHENTIK_BOOTSTRAP_EMAIL: "${DEFAULT_ADMIN_EMAIL}"
LITELLM_POSTGRESQL__PASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
```

### **2. Automatic Initialization**
No manual setup required:
- First run: Copies `secrets-templates/` → `secrets-config/`
- Subsequent runs: Uses existing `secrets-config/`
- Missing config: Auto-recreates from templates

## 📖 **Common Tasks**

### **Adding New Secrets**
1. **Edit base template** (for team changes):
   ```bash
   nano secrets-templates/00-master-secrets.yml.template
   git add secrets-templates/
   git commit -m "Add new secret template"
   ```

2. **Edit your config** (for personal changes):
   ```bash
   nano secrets-config/00-master-secrets.yml.template
   ./create-kubernetes-secrets.sh
   ```

### **Updating Existing Values**
```bash
# Change central passwords
nano secrets-config/00-common-values.env.template

# Or edit specific secrets
nano secrets-config/00-master-secrets.yml.template

# Regenerate
./create-kubernetes-secrets.sh
```

### **Adding New Service Templates**
```bash
# Create new base template
nano secrets-templates/14-myservice-secrets.yml.template

# Auto-initialize user config on next run
./create-kubernetes-secrets.sh
```

### **Updating Existing Templates**
When you update `secrets-templates/` files, you MUST also update `secrets-config/`:

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

**Why**: The generation script prioritizes `secrets-config/` over `secrets-templates/` for user customization.

### **Troubleshooting**

#### **"Template not found" Error**
```bash
# Reset to base templates
rm -rf secrets-config/
./create-kubernetes-secrets.sh
```

#### **"YAML validation failed" Warning**
```bash
# Check syntax manually
kubectl apply --dry-run=client -f kubernetes/kubernetes-secrets.yml

# Common issue: missing namespaces
kubectl create namespace ai
kubectl create namespace authentik
```

#### **"Variable not substituted" Issue**
```bash
# Check common values file
cat secrets-generated/00-common-values.env

# Verify variable names match exactly
grep "DEFAULT_DATABASE_PASSWORD" secrets-config/00-common-values.env.template
```

#### **"New secrets not appearing" Issue**
```bash
# Check if you updated both template and user config
diff secrets-templates/00-master-secrets.yml.template secrets-config/00-master-secrets.yml.template

# If user config is missing your changes, copy them over
cp secrets-templates/00-master-secrets.yml.template secrets-config/00-master-secrets.yml.template

# Regenerate
./create-kubernetes-secrets.sh
```

## 🛡️ **Security Best Practices**

### **✅ Safe Operations**
- Edit files in `secrets-config/` (gitignored)
- Use variable substitution for common values
- Test with `kubectl --dry-run` before applying
- Backup secrets to `terchris/` folder if needed

### **❌ Dangerous Operations**
- Never edit `secrets-templates/` with actual secrets
- Never create copies of `kubernetes-secrets.yml` in git-tracked areas
- Never commit files from `secrets-config/` or `secrets-generated/`
- Never store secrets in documentation or comments

### **🔍 Verification Commands**
```bash
# Verify nothing secret is staged for git
git status

# Verify gitignore is working
git check-ignore secrets-config/
git check-ignore secrets-generated/

# Verify generated secrets work
kubectl apply --dry-run=client -f kubernetes/kubernetes-secrets.yml
```

## 🚀 **Advanced Usage**

### **Multiple Environment Support**
```bash
# Development environment
cp secrets-templates/ dev-secrets-config/
# Edit dev-secrets-config/ with dev values

# Production environment
cp secrets-templates/ prod-secrets-config/
# Edit prod-secrets-config/ with prod values

# Generate for specific environment
SECRETS_CONFIG_DIR=dev-secrets-config ./create-kubernetes-secrets.sh
```

### **Custom Variable Processing**
The system supports any environment variables:
```bash
# In secrets-config/00-common-values.env.template
CUSTOM_API_KEY=your-api-key-here
CUSTOM_DATABASE_HOST=custom.database.com

# In secrets-config/00-master-secrets.yml.template
MY_API_KEY: "${CUSTOM_API_KEY}"
MY_DB_HOST: "${CUSTOM_DATABASE_HOST}"
```

### **Template Validation**
```bash
# Check template syntax before generation
envsubst < secrets-config/00-master-secrets.yml.template | kubectl apply --dry-run=client -f -
```

## 📚 **Related Documentation**

- **🌐 Infrastructure Overview**: `docs/infrastructure-readme.md`
- **🏗️ Git Workflow**: `docs/rules-git-workflow.md`
- **🚦 Ingress Configuration**: `docs/rules-ingress-traefik.md`
- **🤖 AI Environment**: `docs/package-ai-environment-management.md`

## ❓ **FAQ**

**Q: Can I still use the old kubernetes-secrets-template.yml?**
A: Yes! The system automatically detects and uses legacy templates for backward compatibility.

**Q: What happens to my existing secrets?**
A: They continue working unchanged. The new system only affects how secrets are generated.

**Q: How do I share template updates with my team?**
A: Edit `secrets-templates/` and commit to git. Team members run `./create-kubernetes-secrets.sh` to get updates.

**Q: Can I see what variables are available?**
A: Check `secrets-templates/00-common-values.env.template` for all supported variables.

**Q: How do I add secrets for a new service?**
A: Create a new template in `secrets-templates/` or add to the master template, then regenerate.

---

## 📚 **Related Documentation**

- **[rules-secrets-management.md](./rules-secrets-management.md)** - Best practices and rules for secrets handling
- **[hosts-cloud-init-secrets.md](./hosts-cloud-init-secrets.md)** - SSH key setup for cloud-init and Ansible

**💡 Remember**: This system prevents secrets from entering version control while enabling team collaboration on secret structure and templates. Always verify your gitignore is working before committing changes.