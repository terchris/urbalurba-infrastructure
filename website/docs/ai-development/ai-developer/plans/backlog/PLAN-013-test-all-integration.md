# PLAN-013: `./uis test-all` — Full Integration Test Command

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Automate the full integration test as `./uis test-all` — runs the same `./uis deploy`/`./uis undeploy` commands the manual tester runs, for all 23 services.

**Last Updated**: 2026-02-25

---

## Problem Summary

The full integration test requires a manual tester. The tester runs `./uis deploy <service>`, checks exit code, runs `./uis undeploy <service>`, checks exit code — for all 23 services. This should be a single command.

---

## Design: Data-Driven Test Sequence

### Existing metadata we use

Every service script already declares:
- `SCRIPT_REQUIRES` — space-separated dependency list (e.g. `"postgresql redis"`)
- `SCRIPT_PRIORITY` — numeric deployment order (lower = earlier)
- `SCRIPT_ID` — service identifier

The test script reads these from the service scripts via `service-scanner.sh` functions that already exist (`get_all_service_ids`, `find_service_script`).

### How the test sequence is built

1. **Scan all services** using `get_all_service_ids` (already sorts by priority)
2. **Skip services** in a skip list: `SKIP_SERVICES="gravitee tailscale-tunnel cloudflare-tunnel"`
3. **Topological deploy order** — sort by `SCRIPT_PRIORITY`, then resolve `SCRIPT_REQUIRES` so dependencies deploy first
4. **Undeploy in reverse** — services without dependents undeploy first; shared deps (postgresql, redis, nginx) undeploy last

### Three service roles

| Role | Meaning | Example |
|------|---------|---------|
| **foundation** | Deploy first, undeploy last. Never undeployed mid-test. | nginx, postgresql, redis |
| **regular** | Deploy, test, undeploy. Dependencies must be running. | whoami, authentik, grafana |
| **skip** | Not tested (needs external config). | gravitee, tailscale-tunnel, cloudflare-tunnel |

Foundation services are those that appear in other services' `SCRIPT_REQUIRES` (computed automatically). A service that nothing depends on is "regular".

### Test execution order (computed, not hardcoded)

```
1. Deploy all foundation services (sorted by priority)
2. For each regular service (sorted by priority):
   a. Deploy  → record PASS/FAIL
   b. If service has a verify command (e.g. argocd): run it → record PASS/FAIL
   c. Undeploy → record PASS/FAIL
3. Undeploy all foundation services (reverse priority order)
```

### Extensibility

When a new service is added to `provision-host/uis/services/`:
- If it has no `SCRIPT_REQUIRES` and nothing depends on it → automatically tested as "regular"
- If other services depend on it → automatically promoted to "foundation"
- If it needs external config → add its ID to the skip list (one line change)

No hardcoded service lists to maintain except the skip list.

### Output design

Deploy/undeploy commands produce lots of Ansible and kubectl output. All of it streams normally so the user can follow along live. The test script adds clear marker lines with timestamps and a step counter before and after each operation, plus a summary table at the end.

**Before each operation** — bold banner with timestamp and progress:

```
══════════════════════════════════════════════════════════════
[14:30:12] TEST 4/23: deploy whoami
══════════════════════════════════════════════════════════════
```

*...all normal ansible/kubectl output flows here...*

**After each operation** — result line with duration:

```
[14:30:37] RESULT: deploy whoami — PASS (25s)
```

**After all operations** — summary table:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Finished: 2026-02-25 14:58:37
Duration: 28m 25s

SERVICE          DEPLOY   UNDEPLOY  VERIFY
─────────────────────────────────────────────
nginx            PASS     PASS      -
postgresql       PASS     PASS      -
whoami           PASS     PASS      -
authentik        PASS     PASS      -
argocd           PASS     PASS      PASS
...
─────────────────────────────────────────────
Result: 43/43 PASS (0 FAIL)
```

Key details:
- **Timestamps on every marker** — shows when each step started/ended
- **Duration per operation** — makes slow services visible
- **Total duration** — printed at the end so user knows how long the full run took
- **Step counter** `4/23` — number is services (not operations), so user can estimate time remaining
- **No output suppression** — everything streams live, markers are just bookends

### Log file

All console output (markers + ansible/kubectl output) is captured to a log file using `tee`. The log file path is printed at the start and end of the run.

```
Log file: /tmp/uis-test-all-2026-02-25-143012.log
```

This lets the user scroll back through the full output after a long run, or share the log file for debugging.

### Failure behavior: stop on first failure

The test stops immediately when any operation returns a non-zero exit code. This means:
- If `deploy postgresql` fails, the test stops — no point testing services that depend on it
- If `deploy mysql` fails, the test stops — the user fixes the issue and reruns
- The summary table shows what passed and which operation failed

This gives fast feedback. The user fixes one problem at a time and reruns `./uis test-all`.

On failure, the summary shows completed results plus the failed operation:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Finished: 2026-02-25 14:45:10
Duration: 15m 02s
STOPPED: deploy authentik FAILED

SERVICE          DEPLOY   UNDEPLOY  VERIFY
─────────────────────────────────────────────
nginx            PASS     -         -
postgresql       PASS     -         -
redis            PASS     -         -
whoami           PASS     PASS      -
mysql            PASS     PASS      -
authentik        FAIL     -         -
─────────────────────────────────────────────
Result: FAILED at deploy authentik (10/43 operations completed)

Log file: /tmp/uis-test-all-2026-02-25-143012.log
```

---

## Phase 1: Create Test Script

### Tasks

- [ ] 1.1 Create `provision-host/uis/lib/integration-testing.sh` with:
  - `build_test_plan()` — scans services, computes foundation/regular/skip sets, returns ordered plan
  - `run_integration_tests()` — executes the plan, records results
  - `print_test_summary()` — prints PASS/FAIL table and totals

- [ ] 1.2 Implementation details:
  - Use `get_all_service_ids` + `find_service_script` to scan (from `service-scanner.sh`)
  - Source each service script to read `SCRIPT_REQUIRES` and `SCRIPT_PRIORITY`
  - Compute foundation set: any service ID that appears in another service's `SCRIPT_REQUIRES`
  - Skip list: `SKIP_SERVICES="gravitee tailscale-tunnel cloudflare-tunnel"` (single variable, easy to edit)
  - Call `uis-cli.sh deploy <service>` / `uis-cli.sh undeploy <service>` as subprocesses
  - Check exit code (0 = PASS, non-zero = FAIL)
  - Stop on first failure — print summary of what passed and what failed, then exit 1
  - For argocd: also run `uis-cli.sh argocd verify` between deploy and undeploy
  - Track results in arrays: service name, command (deploy/undeploy/verify), result (PASS/FAIL)
  - Capture all output (markers + ansible/kubectl) to log file via `tee`
  - Print log file path at start and end of run

- [ ] 1.3 Support `--dry-run` flag — print the computed test plan without executing

### Validation

`./uis test-all --dry-run` shows the computed plan with foundation/regular/skip grouping.

---

## Phase 2: Wire Into CLI

### Tasks

- [ ] 2.1 Add `source "$LIB_DIR/integration-testing.sh" 2>/dev/null || true` to `uis-cli.sh`
- [ ] 2.2 Add `cmd_test_all()` function that calls `run_integration_tests "$@"`
- [ ] 2.3 Add `test-all)` case to the command router in `main()`
- [ ] 2.4 Add to help text under a new "Testing:" section

### Validation

`./uis test-all --dry-run` works from the host.

---

## Phase 3: Build and Test

### Tasks

- [ ] 3.1 Build image
- [ ] 3.2 Tester runs `./uis test-all` on clean cluster
- [ ] 3.3 All 23 services pass

### Validation

Tester confirms all pass.

---

## Acceptance Criteria

- [ ] `./uis test-all` runs deploy/undeploy for all 23 services using regular `./uis` commands
- [ ] `./uis test-all --dry-run` shows the computed plan without executing
- [ ] Test order respects `SCRIPT_REQUIRES` dependencies (foundations first, dependents after)
- [ ] Stops on first failure with summary of what passed and what failed
- [ ] All output captured to log file (path printed at start and end)
- [ ] Summary table at end with PASS/FAIL per service per operation
- [ ] Timestamps and duration on every operation
- [ ] Exit code 0 = all pass, 1 = any fail
- [ ] Adding a new service requires zero changes (unless it needs to be skipped)

---

## Files to Modify

| File | Action |
|------|--------|
| `provision-host/uis/lib/integration-testing.sh` | **Create** — test orchestration |
| `provision-host/uis/manage/uis-cli.sh` | Add source, command, help text |
