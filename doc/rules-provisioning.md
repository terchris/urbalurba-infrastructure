# Deployment Rules and Standards

**File**: `doc/deployment-rules.md`
**Purpose**: Define mandatory rules and patterns for all cluster deployments
**Target Audience**: Developers, DevOps engineers, and LLMs working with cluster infrastructure
**Last Updated**: September 20, 2025

## 📋 **Overview**

This document establishes mandatory rules for creating deployments in the Urbalurba Infrastructure cluster. These rules are based on proven patterns that ensure reliability, consistency, and maintainability across all services.

## 🎯 **Core Deployment Architecture**

### **Rule 1: Script + Ansible Pattern**
All deployments MUST follow the **Script + Ansible** pattern:

```
scripts/packages/[service].sh  →  ansible/playbooks/[nnn]-setup-[service].yml
     ↑ Minimal orchestration      ↑ Heavy lifting implementation
```

#### **Script Responsibilities** (Keep Minimal):
- ✅ Check prerequisites (kubectl access, basic dependencies)
- ✅ Call Ansible playbook with proper parameters
- ✅ Display final success/failure message
- ❌ **NO business logic** - delegate to Ansible
- ❌ **NO complex operations** - keep scripts simple

#### **Ansible Playbook Responsibilities** (Heavy Lifting):
- ✅ All deployment logic and verification
- ✅ Resource creation and configuration
- ✅ Comprehensive testing and validation
- ✅ Error handling with proper retry mechanisms
- ✅ Status reporting and troubleshooting information

### **Example Structure**:
```bash
# scripts/packages/litellm.sh
#!/bin/bash
set -e
echo "🚀 Deploying LiteLLM AI Gateway..."
ansible-playbook ansible/playbooks/210-setup-litellm.yml
echo "✅ LiteLLM deployment complete"
```

```yaml
# ansible/playbooks/210-setup-litellm.yml
- name: Deploy LiteLLM with comprehensive validation
  # ... all the actual deployment logic
```

## 🧪 **Testing Requirements**

### **Rule 2: No .localhost Testing from Host Context**

**❌ CRITICAL ERROR - Never Do This**:
```yaml
# WRONG: Testing .localhost from Ansible (host context)
- name: Test service
  ansible.builtin.uri:
    url: "http://service.localhost/health"  # Will fail!
```

**Problem**: Ansible runs on the host machine where `.localhost` domains resolve to `127.0.0.1` (the host itself), not to the Traefik ingress controller running in the cluster.

**Background**: The cluster uses a dual-context DNS architecture (detailed in `doc/rules-ingress-traefik.md`):
- **External/Browser Context**: `service.localhost` → `127.0.0.1` → Traefik → Service ✅
- **Internal/Pod Context**: `service.localhost` → CoreDNS rewrite → ClusterIP → Service ✅
- **Host/Ansible Context**: `service.localhost` → `127.0.0.1` (host machine) ❌

### **Rule 3: Mandatory Cluster-Internal Testing**

**✅ CORRECT: Use kubectl run for all service tests**:
```yaml
# CORRECT: Test from within cluster using temporary pod
- name: Test service connectivity from within cluster
  ansible.builtin.shell: |
    kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -n {{ namespace }} -- \
    curl -s -w "HTTP_CODE:%{http_code}" http://{{ service }}:{{ port }}/health
  register: service_test
  retries: 5
  delay: 5
  until: service_test.rc == 0 and (service_test.stdout.find('HTTP_CODE:200') != -1 or service_test.stdout.find('HTTP_CODE:401') != -1)
```

### **Why This Works**:
- **✅ True Cluster Context**: Test pod runs inside cluster with proper DNS resolution
- **✅ Service-to-Service Testing**: Tests actual communication paths other pods will use
- **✅ Temporary & Clean**: `--rm` automatically removes test pod
- **✅ No Dependencies**: Doesn't require existing pods to have curl/python
- **✅ Reliable**: Uses proven pattern from working playbooks

### **Testing Sequence Requirements**:
1. **Internal Service Test**: Verify service responds within cluster
2. **API Functionality Test**: Test actual API endpoints with authentication
3. **IngressRoute Verification**: Confirm Traefik routing is configured
4. **Integration Test**: Verify service integrates with dependencies

## 🔄 **Error Handling Rules**

### **Rule 4: No Error Ignoring for Critical Dependencies**

**❌ WRONG: Ignoring errors when next steps depend on success**:
```yaml
- name: Deploy database
  command: helm install postgres ...
  ignore_errors: true  # WRONG! Next steps need this to succeed

- name: Create application tables  # Will fail if database not deployed
  command: kubectl exec postgres -- psql ...
```

**✅ CORRECT: Fail fast for critical dependencies**:
```yaml
- name: Deploy database
  command: helm install postgres ...
  # No ignore_errors - let it fail if database can't deploy

- name: Wait for database to be ready
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: "{{ namespace }}"
    label_selectors:
      - app=postgresql
  register: db_pods
  retries: 20
  delay: 15
  until: db_pods.resources | length > 0 and db_pods.resources[0].status.phase == "Running"

- name: Create application tables
  command: kubectl exec postgres -- psql ...
  # Now safe to run because database is verified ready
```

### **Rule 5: When to Use ignore_errors**

**✅ Safe to ignore errors**:
- Cleanup operations (`pkill kubectl proxy`)
- Optional optimizations (cache warmup)
- Non-critical status reporting
- Tests that don't block deployment progress

**❌ Never ignore errors for**:
- Service deployment steps
- Database/storage setup
- Required secret creation
- Network/ingress configuration
- Any step that subsequent steps depend on

## 🔍 **Verification Standards**

### **Rule 6: Comprehensive Verification Required**

Every deployment MUST include:

1. **Pod Readiness Check with Progress Feedback**:
```yaml
- name: Wait for service pods to be ready (with progress indicators)
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: "{{ namespace }}"
    label_selectors:
      - app.kubernetes.io/name={{ service_name }}
  register: service_pods
  retries: 20
  delay: 15
  until: service_pods.resources | length > 0 and service_pods.resources[0].status.phase == "Running"
```

2. **Service Connectivity Test**:
```yaml
- name: Test service connectivity from within cluster
  ansible.builtin.shell: |
    kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -n {{ namespace }} -- \
    curl -s -w "HTTP_CODE:%{http_code}" http://{{ service }}:{{ port }}/health
```

3. **IngressRoute Verification**:
```yaml
- name: Verify IngressRoute is created
  kubernetes.core.k8s_info:
    api_version: traefik.io/v1alpha1
    kind: IngressRoute
    namespace: "{{ namespace }}"
    name: "{{ service_name }}"
  register: ingress_check
  retries: 5
  delay: 2
  until: ingress_check.resources | length > 0
```

4. **Functional API Test**:
```yaml
- name: Test API functionality
  # Use kubectl proxy or port-forward for API-specific tests
```

### **Rule 7: Progress Feedback for Long-Running Tasks**

All tasks that may take longer than 30 seconds MUST provide progress feedback to prevent the appearance of hanging.

**❌ WRONG: Silent long-running tasks**:
```yaml
# WRONG: 10 minutes of silence - appears to hang
- name: Wait for pods to be ready
  shell: kubectl wait --timeout=600s ...
```

**✅ CORRECT: Ansible retries with progress indicators**:
```yaml
# CORRECT: Progress every 15 seconds with retry counters
- name: Wait for pods to be ready (with progress indicators)
  kubernetes.core.k8s_info:
    kind: Pod
    label_selectors: [...]
  retries: 40     # Clear total attempt count
  delay: 15       # Regular progress intervals
  until: condition_met
```

**Expected User Experience**:
```
FAILED - RETRYING: [localhost]: Wait for pods (40 retries left).
FAILED - RETRYING: [localhost]: Wait for pods (39 retries left).
FAILED - RETRYING: [localhost]: Wait for pods (38 retries left).
...
ok: [localhost]
```

**Benefits**:
- ✅ User sees system is active, not hanging
- ✅ Clear countdown shows progress and remaining time
- ✅ Predictable feedback rhythm (every 15 seconds)
- ✅ Transparent about retry attempts and timeouts

### **Rule 8: Task Naming and Numbering Standards**

All Ansible tasks MUST follow consistent naming and numbering conventions:

**Mandatory Requirements**:
- ✅ **Sequential numbering**: Tasks numbered 1, 2, 3... in execution order
- ✅ **Descriptive names**: Clear action description after the number
- ✅ **Consistent format**: `- name: N. Action description`

**✅ CORRECT Examples**:
```yaml
- name: 1. Deploy database via Helm
- name: 2. Wait for database pods to be ready
- name: 3. Test database connectivity from within cluster
- name: 4. Apply database ingress configuration
- name: 5. Display database deployment status
```

**❌ WRONG Examples**:
```yaml
- name: Deploy database        # Missing number
- name: 3. Deploy database     # Wrong sequence (should be 1)
- name: 2. Wait               # Not descriptive enough
- name: Step 2 - Deploy       # Wrong format
```

**Benefits**:
- ✅ **Easy debugging**: Error messages show exact task sequence
- ✅ **Clear progress**: Users see completion percentage
- ✅ **Maintainability**: Easy to reference specific tasks in documentation
- ✅ **Troubleshooting**: "Failed at task 7" immediately identifies the problem

**Refactoring Rule**: When adding/removing tasks, renumber all subsequent tasks to maintain sequence.

### **Rule 9: Status Reporting Standards**

Every playbook MUST end with a comprehensive status report:

```yaml
- name: Display final deployment status
  ansible.builtin.debug:
    msg:
      - "==============================================="
      - "🚀 {{ service_name | title }} Deployment Status"
      - "==============================================="
      - ""
      - "✅ SUCCESS - All components verified and running"
      - ""
      - "🔄 Status:"
      - "• Service connectivity: ✅ Internal cluster communication verified"
      - "• API responding: ✅ Functional tests passed"
      - "• IngressRoute: ✅ Traefik routing configured"
      - ""
      - "🌐 Access Instructions:"
      - "• Port-forward: kubectl port-forward svc/{{ service_name }} {{ port }}:{{ port }} -n {{ namespace }}"
      - "• Ingress: http://{{ service_name }}.localhost"
      - ""
      - "🔧 Troubleshooting:"
      - "• Check pod status: kubectl get pods -n {{ namespace }}"
      - "• View logs: kubectl logs -f <pod-name> -n {{ namespace }}"
      - "==============================================="
```

## 📁 **File Organization Rules**

### **Rule 10: Utility Playbook Structure**

All files in `ansible/playbooks/utility/` MUST be complete playbooks, not just task lists.

**❌ WRONG: Task list format**:
```yaml
# utility/u06-database-setup.yml - WRONG!
- name: Create database user
  postgresql_user: ...
- name: Create database
  postgresql_db: ...
```

**✅ CORRECT: Complete playbook format**:
```yaml
# utility/u06-database-setup.yml - CORRECT!
---
- name: Database setup utility
  hosts: localhost
  gather_facts: false
  vars:
    database_name: "{{ database_name | default('myapp') }}"
    database_user: "{{ database_user | default('myuser') }}"
  tasks:
    - name: 1. Create database user
      postgresql_user: ...
    - name: 2. Create database
      postgresql_db: ...
```

**Usage in Main Playbooks**:
```yaml
# Main playbook imports utility
- import_playbook: utility/u06-database-setup.yml
  vars:
    database_name: "openwebui"
    database_user: "openwebui"
```

**Benefits**:
- ✅ **Reusable**: Can be run standalone or imported
- ✅ **Testable**: Can be tested independently
- ✅ **Parameterized**: Accepts variables for different use cases
- ✅ **Complete**: Has proper playbook structure with hosts, vars, tasks
- ✅ **Maintainable**: Clear separation of concerns

### **Rule 11: Helm Repository Management**

Every playbook that uses Helm charts MUST be responsible for managing its required Helm repositories.

**Mandatory Requirements**:
- ✅ **Check existing repositories**: Verify what's already configured
- ✅ **Add missing repositories**: Add only repositories that are needed and missing
- ✅ **Update repositories**: Refresh repository indexes before installation
- ✅ **Self-contained**: Never assume repositories are pre-configured

**✅ CORRECT Pattern**:
```yaml
- name: N. Check existing Helm repositories
  ansible.builtin.command: helm repo list
  register: helm_repo_list
  changed_when: false

- name: N+1. Add required Helm repositories if missing
  kubernetes.core.helm_repository:
    name: "{{ item.name }}"
    repo_url: "{{ item.url }}"
  loop:
    - { name: 'bitnami', url: 'https://charts.bitnami.com/bitnami' }
    - { name: 'open-webui', url: 'https://helm.openwebui.com/' }
  when: item.name not in helm_repo_list.stdout

- name: N+2. Update Helm repositories
  ansible.builtin.command: helm repo update
  changed_when: false

- name: N+3. Deploy service via Helm
  ansible.builtin.command: >
    helm upgrade --install {{ service_name }} {{ chart_name }}
    -f {{ config_file }}
    --namespace {{ namespace }}
```

**Benefits**:
- ✅ **Self-contained**: Playbook doesn't depend on external setup
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Efficient**: Only adds missing repositories
- ✅ **Reliable**: Fresh repository indexes before deployment
- ✅ **Debuggable**: Clear separation of repository and deployment steps

**❌ WRONG: Assuming pre-configured repositories**:
```yaml
# WRONG: Assumes repositories are already configured
- name: Deploy service via Helm
  helm: chart=some-chart/service-name ...  # May fail if repo missing
```

### **Rule 12: Utility Playbook Error Handling**

When calling utility playbooks from main playbooks, MUST implement "quiet success, verbose failure" pattern.

**Mandatory Requirements**:
- ✅ **Capture output**: Always `register` the result of utility playbook calls
- ✅ **Silent success**: No output display when utility playbook succeeds
- ✅ **Verbose failure**: Show full utility playbook output when it fails
- ✅ **Proper error handling**: Use `failed_when` to catch non-zero exit codes

**❌ WRONG: No error diagnostics**:
```yaml
# WRONG: Utility failure provides no diagnostic information
- name: 1. Set up database
  ansible.builtin.shell: |
    ansible-playbook utility/database-setup.yml
  register: db_result
  failed_when: db_result.rc != 0
```

**✅ CORRECT: Error diagnostics on failure**:
```yaml
# CORRECT: Shows utility output only when debugging is needed
- name: 1. Set up database
  ansible.builtin.shell: |
    ansible-playbook utility/database-setup.yml -e operation=create
  args:
    chdir: /path/to/playbooks
  register: db_result
  changed_when: db_result.rc == 0
  failed_when: db_result.rc != 0

- name: 1.1. Display utility playbook output on failure
  ansible.builtin.debug:
    msg:
      - "❌ Database setup failed!"
      - "Full output from utility playbook:"
      - "{{ db_result.stdout_lines }}"
  when: db_result.rc != 0
```

**Benefits**:
- ✅ Clean output during normal operations (quiet success)
- ✅ Full diagnostic information when troubleshooting is needed (verbose failure)
- ✅ No subprocess output buffering issues
- ✅ Maintains utility playbook independence

### **Rule 13: Automatic Execution System**

The cluster uses an **automatic execution system** during full provisioning that executes scripts based on their location in the filesystem.

**How Auto-Execution Works**:

The `provision-host/kubernetes/provision-kubernetes.sh` script automatically discovers and executes setup scripts using this algorithm:

1. **Directory Discovery**: Finds all numbered directories `[0-9]*` and sorts them numerically
2. **Script Discovery**: In each directory, finds scripts matching pattern `[0-9]*.sh` and sorts them numerically
3. **Sequential Execution**: Runs scripts in order across directories (01-core, 02-databases, 07-ai, etc.)
4. **Depth Limitation**: Only searches at `maxdepth 1` - **excludes subdirectories like `not-in-use/`**

**Critical Implementation Details**:
```bash
# From provision-kubernetes.sh lines 145-151
directories=$(find . -maxdepth 1 -type d -name "[0-9]*" | sort -n)
for dir in $directories; do
    scripts=$(find "$dir" -maxdepth 1 -type f -name "[0-9]*.sh" | sort -n)
```

**Auto-Execution Rules**:

**✅ WILL Auto-Execute**:
- Scripts directly in numbered category directories
- Example: `provision-host/kubernetes/07-ai/01-setup-litellm-openwebui.sh`
- Pattern: `[nn]-[category]/[nn]*.sh`

**❌ WILL NOT Auto-Execute**:
- Scripts in `not-in-use/` subdirectories
- Example: `provision-host/kubernetes/07-ai/not-in-use/01-remove-service.sh`
- Any script in subdirectories beyond `maxdepth 1`

**Managing Script Activation**:

```bash
# Activate a script for auto-execution
mv provision-host/kubernetes/07-ai/not-in-use/01-setup-service.sh \
   provision-host/kubernetes/07-ai/

# Deactivate a script from auto-execution
mv provision-host/kubernetes/07-ai/01-setup-service.sh \
   provision-host/kubernetes/07-ai/not-in-use/
```

**Security by Design**:
- **Setup scripts**: Move to category directory to enable auto-deployment
- **Removal scripts**: Keep in `not-in-use/` to prevent accidental deletion
- **Experimental scripts**: Keep in `not-in-use/` until ready for production

**Execution Order Example**:
```
01-core-systems/020-setup-nginx.sh           # Executes first
02-databases/05-setup-postgres.sh            # Executes second
07-ai/01-setup-litellm-openwebui.sh         # Executes during AI phase
07-ai/02-setup-open-webui.sh                # Executes after 01
07-ai/03-setup-litellm.sh                   # Executes after 02
07-ai/not-in-use/01-remove-service.sh       # NEVER auto-executes
```

**Benefits**:
- ✅ **Predictable**: Clear execution order based on filesystem location
- ✅ **Safe**: Removal scripts protected from accidental execution
- ✅ **Flexible**: Easy to activate/deactivate services by moving files
- ✅ **Organized**: Physical file organization reflects deployment sequence
- ✅ **Auditable**: File location immediately shows deployment status

### **Rule 14: Consistent File Naming and Numbering**

```
scripts/packages/[service-name].sh
ansible/playbooks/[nnn]-setup-[service-name].yml
ansible/playbooks/utility/[unn]-[purpose].yml
manifests/[nnn]-[service-name]-[component].yaml
provision-host/kubernetes/[nn]-[category]/[nn]-setup-[service].sh
```

**Numbering Convention**:
- `000-099`: Core infrastructure (storage, networking, DNS)
- `040-099`: Data services (databases, caches, message queues)
- `200-229`: AI services (OpenWebUI, LiteLLM, Ollama)
- `070-079`: Authentication (Authentik, OAuth providers)
- `030-039`: Observability (monitoring, logging, tracing)
- `600-799`: Management tools (admin interfaces, development tools)

### **Rule 15: Ingress Standards**

All services MUST follow the **Traefik Ingress Standards** defined in `doc/rules-ingress-traefik.md`.

**Mandatory Requirements**:
- ✅ Use **only Traefik IngressRoute CRDs** (never standard Kubernetes Ingress)
- ✅ Follow **HostRegexp patterns** for multi-domain support
- ✅ Use **correct API version** and **proper labeling**
- ✅ Apply **authentication middleware** for protected services

**See `doc/rules-ingress-traefik.md` for**:
- Complete IngressRoute templates and examples
- HostRegexp pattern explanations
- Authentication integration patterns
- API version requirements
- Working examples from the codebase

## 🚨 **Common Anti-Patterns to Avoid**

### **❌ Anti-Pattern 1: Shell Script Logic**
```bash
# WRONG: Business logic in shell script
if helm list | grep -q postgres; then
  echo "Postgres exists, upgrading..."
  helm upgrade postgres ...
else
  echo "Installing postgres..."
  helm install postgres ...
fi
```
**Solution**: Move all logic to Ansible playbooks.

### **❌ Anti-Pattern 2: localhost Testing**
```yaml
# WRONG: Testing localhost from host context
- name: Test service
  uri:
    url: "http://service.localhost/api"
```
**Solution**: Use kubectl run with curl container.

### **❌ Anti-Pattern 3: Missing Retry Logic**
```yaml
# WRONG: No retry for potentially slow operations
- name: Wait for pod
  shell: kubectl get pod service-pod
```
**Solution**: Use retries/delay/until pattern.

### **❌ Anti-Pattern 4: Ignoring Critical Errors**
```yaml
# WRONG: Ignoring deployment failures
- name: Deploy service
  command: helm install service ...
  ignore_errors: true
```
**Solution**: Let critical failures fail fast.

### **❌ Anti-Pattern 5: Silent Long-Running Tasks**
```yaml
# WRONG: No progress feedback for long operations
- name: Wait for deployment
  shell: kubectl wait --timeout=600s ...
```
**Solution**: Use Ansible retries with progress indicators.

### **❌ Anti-Pattern 6: Utility Files as Task Lists**
```yaml
# WRONG: utility/database-setup.yml as task list
- name: Create user
  postgresql_user: ...
- name: Create database
  postgresql_db: ...
```
**Solution**: Write complete playbooks with hosts, vars, and tasks sections.

### **❌ Anti-Pattern 7: Assuming Pre-configured Helm Repositories**
```yaml
# WRONG: Assuming repositories are already configured
- name: Deploy service
  helm: chart=some-repo/service-name ...  # May fail if repo missing
```
**Solution**: Manage Helm repositories within the playbook (check, add, update).

## 📚 **Reference Documentation**

### **Related Cluster Documentation**:
- **🚦 Ingress Standards**: `doc/rules-ingress-traefik.md` - Comprehensive Traefik IngressRoute patterns
- **🌐 Networking Overview**: `doc/networking-readme.md` - Cluster networking architecture
- **🏗️ Infrastructure Guide**: `doc/infrastructure-readme.md` - Overall cluster architecture
- **🤖 AI Environment**: `doc/package-ai-environment-management.md` - AI-specific deployment patterns

### **Key Concepts from Traefik Documentation**:
- **HostRegexp Patterns**: Multi-domain routing with `HostRegexp(\`service\\..+\`)`
- **API Version**: Use `traefik.io/v1alpha1` (not `traefik.io/v1`)
- **DNS Resolution**: Dual-context architecture for localhost routing
- **Authentication**: Forward auth middleware patterns for protected services
- **Priority System**: Route matching order and conflict resolution

### **Working Examples in Codebase**:
- **✅ Good**: `ansible/playbooks/020-setup-nginx.yml` - Proper testing with kubectl run
- **✅ Good**: `ansible/playbooks/210-setup-litellm.yml` - Comprehensive verification
- **✅ Good**: `manifests/071-whoami-public-ingressroute.yaml` - Proper IngressRoute pattern
- **✅ Good**: `manifests/078-whoami-protected-ingressroute.yaml` - Authentication integration

### **Testing Pattern Reference**:
```yaml
# From ansible/playbooks/020-setup-nginx.yml (lines 123-131)
- name: Test connectivity from within the cluster
  ansible.builtin.shell: |
    kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never --context {{ kube_context }} -- \
    curl -s http://nginx.default.svc.cluster.local:{{ port }}/{{ file }}
  register: curl_test
  ignore_errors: true
  changed_when: false
```

### **IngressRoute Patterns**:
See `doc/rules-ingress-traefik.md` for complete IngressRoute examples and patterns.

## 🎯 **Enforcement**

### **For Human Developers**:
- All pull requests must follow these rules
- Peer review must verify compliance
- No exceptions without documented justification

### **For LLMs and AI Assistants**:
- These rules are **MANDATORY** and override any default behavior
- Never suggest .localhost testing from host context
- Always use kubectl run pattern for cluster testing
- Never ignore errors for dependencies
- Always follow the Script + Ansible pattern

### **Validation Checklist**:
- [ ] Uses Script + Ansible pattern
- [ ] Tests using kubectl run (not .localhost from host)
- [ ] Includes comprehensive verification steps
- [ ] Does not ignore errors for critical dependencies
- [ ] Provides progress feedback for long-running tasks (>30s)
- [ ] Uses sequential task numbering (1, 2, 3...)
- [ ] Utility files are complete playbooks (not task lists)
- [ ] Manages required Helm repositories within playbook
- [ ] Understands auto-execution system (active vs not-in-use placement)
- [ ] Uses Traefik IngressRoute (not standard Ingress)
- [ ] Follows file naming conventions
- [ ] Includes proper status reporting

## 🔄 **Continuous Improvement**

These rules are living standards based on:
- **Proven patterns** from working deployments
- **Lessons learned** from debugging failures
- **Cluster architecture** requirements
- **Team experience** and best practices

**Update Process**:
1. Propose rule changes via pull request
2. Test changes with actual deployments
3. Update documentation with examples
4. Train team on new patterns

This ensures our deployment standards evolve while maintaining reliability and consistency across all cluster services.