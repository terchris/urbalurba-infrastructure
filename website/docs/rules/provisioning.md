# Provisioning Rules

How to write deployment playbooks and service scripts for UIS. These patterns ensure reliability, consistency, and maintainability across all services.

For how services are discovered and orchestrated by the UIS CLI, see [Kubernetes Deployment Rules](./kubernetes-deployment.md).

## Metadata + Ansible Pattern

All deployments follow the **Metadata + Ansible** pattern:

```
service-*.sh metadata  →  ansible/playbooks/[nnn]-setup-[service].yml
   ↑ Declarative config      ↑ All deployment logic
```

**Service metadata** (in `provision-host/uis/services/<category>/`) declares identity, dependencies, and health checks. It contains no business logic — only variable assignments.

**Ansible playbooks** (in `ansible/playbooks/`) handle all deployment logic: resource creation, configuration, testing, error handling, and status reporting.

```bash
# Metadata declares the playbook
# provision-host/uis/services/ai/service-litellm.sh
SCRIPT_ID="litellm"
SCRIPT_PLAYBOOK="210-setup-litellm.yml"
SCRIPT_REQUIRES="postgresql"
```

### Before creating a new playbook

1. Search `ansible/playbooks/` for existing implementations
2. Check if existing playbooks support multiple operations via parameters
3. Extend existing playbooks rather than create new ones when possible
4. Create new playbooks only when no existing playbook handles the service

### Naming conventions

- **Setup playbook**: `[NNN]-setup-[service-name].yml`
- **Remove playbook**: `[NNN]-remove-[service-name].yml` (same number prefix)
- Every service with `SCRIPT_PLAYBOOK` should have a corresponding `SCRIPT_REMOVE_PLAYBOOK`

See [Naming Conventions](./naming-conventions.md) for the complete numbering scheme.

## No .localhost Testing from Host Context

**Never test `.localhost` URLs from Ansible**:

```yaml
# WRONG: .localhost resolves to the host machine, not the cluster
- name: Test service
  ansible.builtin.uri:
    url: "http://service.localhost/health"  # Will fail!
```

Ansible runs on the host machine where `.localhost` resolves to `127.0.0.1` (the host itself), not to Traefik in the cluster.

**Always use `kubectl run` for cluster-internal testing**:

```yaml
# CORRECT: Test from within the cluster using a temporary pod
- name: Test service connectivity from within cluster
  ansible.builtin.shell: |
    kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -n {{ namespace }} -- \
    curl -s -w "HTTP_CODE:%{http_code}" http://{{ service }}:{{ port }}/health
  register: service_test
  retries: 5
  delay: 5
  until: service_test.rc == 0 and (service_test.stdout.find('HTTP_CODE:200') != -1 or service_test.stdout.find('HTTP_CODE:401') != -1)
```

This runs inside the cluster with proper DNS resolution. The `--rm` flag automatically cleans up the test pod.

## Error Handling

### Fail fast for critical dependencies

Never use `ignore_errors: true` when subsequent steps depend on success:

```yaml
# WRONG: Next step depends on database being deployed
- name: Deploy database
  command: helm install postgres ...
  ignore_errors: true

# CORRECT: Let it fail, then wait for readiness before proceeding
- name: Deploy database
  command: helm install postgres ...

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
```

### When `ignore_errors` is acceptable

- Cleanup operations (`pkill kubectl proxy`)
- Optional optimizations (cache warmup)
- Non-critical status reporting
- Tests that don't block deployment progress

## Verification Standards

Every deployment must include these verification steps:

### 1. Two-stage pod readiness check (recommended)

**Stage 1 — Wait for Running** (pod scheduled, containers started):

```yaml
- name: Wait for service pods to be running
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: "{{ namespace }}"
    label_selectors:
      - app.kubernetes.io/name={{ service_name }}
  register: service_pods
  retries: 20
  delay: 15
  until: >
    service_pods.resources | length > 0 and
    service_pods.resources[0].status.phase == "Running"
```

**Stage 2 — Wait for Ready** (application initialized, readiness probes passing):

```yaml
- name: Wait for service pods to be fully ready (1/1)
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: "{{ namespace }}"
    label_selectors:
      - app.kubernetes.io/name={{ service_name }}
  register: service_pods_ready
  retries: 30
  delay: 10
  until: >
    service_pods_ready.resources | length > 0 and
    service_pods_ready.resources[0].status.containerStatuses[0].ready == true
```

### 2. Service connectivity test

```yaml
- name: Test service connectivity from within cluster
  ansible.builtin.shell: |
    kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -n {{ namespace }} -- \
    curl -s -w "HTTP_CODE:%{http_code}" http://{{ service }}:{{ port }}/health
```

### 3. IngressRoute verification

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

## Progress Feedback

All tasks taking longer than 30 seconds must provide progress feedback. Use Ansible retries instead of silent `kubectl wait`:

```yaml
# WRONG: 10 minutes of silence
- name: Wait for pods
  shell: kubectl wait --timeout=600s ...

# CORRECT: Progress every 15 seconds
- name: Wait for pods to be ready
  kubernetes.core.k8s_info:
    kind: Pod
    label_selectors: [...]
  retries: 40
  delay: 15
  until: condition_met
```

Output looks like:
```
FAILED - RETRYING: [localhost]: Wait for pods (40 retries left).
FAILED - RETRYING: [localhost]: Wait for pods (39 retries left).
ok: [localhost]
```

## Retry and Timeout Guidelines

| Use Case | Retries | Delay | Total |
|----------|---------|-------|-------|
| Lightweight services | 20 | 15s | 5 min |
| Heavy container images (e.g., OpenWebUI) | 80 | 15s | 20 min |
| HTTP connectivity tests | 15 | 15s | ~4 min |
| Resource existence checks | 5 | 2s | 10 sec |

## Task Naming and Numbering

All Ansible tasks must be sequentially numbered with descriptive names:

```yaml
- name: 1. Display deployment information
- name: 2. Deploy database via Helm
- name: 3. Wait for database pods to be ready
- name: 4. Test database connectivity from within cluster
- name: 5. Apply database ingress configuration
- name: 6. Display deployment status
```

When adding or removing tasks, renumber all subsequent tasks to maintain the sequence.

### First task: Display deployment information

Every playbook must start with a deployment context task:

```yaml
- name: 1. Display deployment information
  ansible.builtin.debug:
    msg:
      - "======================================"
      - "Grafana Deployment"
      - "File: ansible/playbooks/034-setup-grafana.yml"
      - "======================================"
      - "Target Host: {{ target_host }}"
      - "Namespace: {{ namespace }}"
      - "Component: {{ component_name }}"
```

### Last task: Status report

Every playbook must end with a summary showing what was deployed, access instructions, and troubleshooting commands.

## Utility Playbooks

All files in `ansible/playbooks/utility/` must be complete playbooks, not task lists:

```yaml
# WRONG: bare task list
- name: Create database user
  postgresql_user: ...

# CORRECT: complete playbook
---
- name: Database setup utility
  hosts: localhost
  gather_facts: false
  vars:
    database_name: "{{ database_name | default('myapp') }}"
  tasks:
    - name: 1. Create database user
      postgresql_user: ...
```

This makes utility playbooks runnable standalone, testable independently, and importable via `import_playbook`.

### Quiet success, verbose failure

When calling utility playbooks, capture output and only display it on failure:

```yaml
- name: 1. Set up database
  ansible.builtin.shell: |
    ansible-playbook utility/database-setup.yml -e operation=create
  register: db_result
  failed_when: db_result.rc != 0

- name: 1.1. Display utility output on failure
  ansible.builtin.debug:
    msg: "{{ db_result.stdout_lines }}"
  when: db_result.rc != 0
```

## Helm Repository Management

Every playbook using Helm charts must manage its own repositories — never assume repos are pre-configured:

```yaml
- name: Check existing Helm repositories
  ansible.builtin.command: helm repo list
  register: helm_repo_list
  changed_when: false

- name: Add required Helm repositories if missing
  kubernetes.core.helm_repository:
    name: "{{ item.name }}"
    repo_url: "{{ item.url }}"
  loop:
    - { name: 'bitnami', url: 'https://charts.bitnami.com/bitnami' }
  when: item.name not in helm_repo_list.stdout

- name: Update Helm repositories
  ansible.builtin.command: helm repo update
  changed_when: false
```

## Ingress Standards

All services must use Traefik IngressRoute CRDs with HostRegexp patterns for multi-domain support. See [Ingress & Networking Rules](./ingress-traefik.md) for complete patterns.

## Related Documentation

- **[Kubernetes Deployment Rules](./kubernetes-deployment.md)** — UIS CLI, service metadata, deploy flow
- **[Ingress & Networking Rules](./ingress-traefik.md)** — Traefik IngressRoute patterns
- **[Naming Conventions](./naming-conventions.md)** — File and resource naming
- **[Secrets Management Rules](./secrets-management.md)** — Credential handling
