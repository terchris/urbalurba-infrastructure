---
title: Talk Protocol
sidebar_position: 4
---

# Talk — AI-to-AI Testing Protocol

Talk is a file-based communication protocol that enables two separate Claude Code sessions to collaborate on testing. One session develops and builds, the other tests as a fresh user. They communicate by appending messages to a shared `talk.md` file.

## Why

Automated tests verify that code works mechanically. Talk sessions verify that the **user experience** works — that deploy commands produce sensible output, that browser UIs show the right data, and that the documentation matches reality. The tester operates as a new user would, following instructions without knowledge of the implementation.

## Participants

| Role | What they do |
|------|-------------|
| **Contributor** | Maintains the codebase, builds the container, writes test instructions, fixes issues |
| **Tester** (uis-user1) | Follows instructions exactly, reports results, suggests improvements |

The contributor works in the main repo. The tester works in a separate directory with only the `./uis` wrapper and the `talk/` folder. They never share a Claude Code session — the `talk.md` file is their only communication channel.

## Where the Talk Folder Lives

The `talk/` folder is located in the **tester's directory**, outside the main repo. This is critical because talk sessions routinely exchange sensitive information — passwords, secrets, API tokens, and service credentials that the tester needs to verify deployments. Keeping the talk folder outside the repo ensures this sensitive data is never accidentally committed or pushed.

```
testing/uis1/              ← tester's working directory
├── talk/                  ← talk folder (NOT in the repo)
│   ├── README.md          ← protocol documentation
│   ├── talk.md            ← active session
│   ├── talk1.md           ← archived session 1
│   ├── talk2.md           ← archived session 2
│   └── ...
└── uis                    ← UIS wrapper script
```

Both the contributor and the tester have access to this folder. The contributor writes test instructions and reads results from it. The tester reads instructions and appends results.

## How It Works

```
Contributor                              Tester
    │                                       │
    ├── builds container (./uis build)      │
    ├── writes test instructions ──────────►│
    │                                       ├── reads instructions
    │                                       ├── runs commands
    │◄────────────── reports results ───────┤
    ├── reviews results                     │
    ├── fixes issues if needed              │
    ├── rebuilds container                  │
    ├── writes next round ─────────────────►│
    │                                       ├── tests again
    │◄────────────── reports results ───────┤
    └── all tests pass → done               │
```

## Session Lifecycle

1. Contributor archives the previous `talk.md` by renaming it to `talk<N>.md` (next number)
2. Contributor creates a fresh `talk.md` with a header and test instructions
3. Tester reads, executes, appends results
4. Contributor reviews, fixes issues, appends next round
5. Repeat until all tests pass

## File Format

### Session Header

```markdown
# Talk - [Feature Name]

**Date**: 2026-03-13
**Previous**: [talk24.md](talk24.md) — Previous session title
**Plan**: [PLAN-xyz.md](path/to/plan)

**What changed**:
- Summary of changes being tested

---
```

### Messages

Messages are numbered sequentially. The contributor writes test steps with expected output. The tester reports actual results.

```markdown
## Contributor Message 1

Instructions with numbered steps and expected output.

### Step 1: Restart with updated container

\`\`\`bash
UIS_IMAGE=uis-provision-host:local ./uis restart
\`\`\`

Expected: Container restarts successfully.

---

## UIS-USER1 - Message 2

### Step 1: Restart with updated container

**Result:** PASS — Container restarted successfully.
```

## Contributor Checklist

Before writing test instructions:

1. **Build the container** — `./uis build` so the tester gets the updated code
2. **Tell the tester to restart** — `UIS_IMAGE=uis-provision-host:local ./uis restart`
3. **Write specific expected output** for each step so the tester knows what to compare against
4. **Include browser tests** when testing UI changes (with exact URLs and what should appear)

## Rules

1. Always append to `talk.md` — never delete previous messages
2. Include full command output when reporting results
3. Report both successes and failures with exact error messages
4. Wait for the other party to respond before continuing
5. The tester may suggest improvements — these often catch real UX issues

## Session Archive

Sessions are archived as `talk1.md`, `talk2.md`, etc. in the talk folder. Over 24 sessions have been completed, covering everything from initial environment setup through service deployments, CLI features, and catalog generation.

## What Gets Caught

Talk sessions have caught issues that automated tests miss:

- **Wrong URLs** in documentation (e.g., `/apis` vs `/api-docs` in Backstage)
- **Rendering errors** in UIs (e.g., OpenAPI renderer failing on text definitions)
- **Missing annotations** on generated entities (e.g., K8s annotations not inherited by API entities)
- **Confusing output** from CLI commands
- **Missing steps** in deployment workflows (e.g., secrets not regenerated after template changes)

These are the kinds of problems a real user would hit but unit tests would never find.

## Example Session

This is a trimmed real session from testing Backstage API entities. It shows the full cycle: test instructions, results, a bug discovered, a fix applied, and a tester suggestion that led to an improvement.

<details>
<summary>Talk - Backstage API Entities (session 25)</summary>

```markdown
# Talk - Backstage API Entities

**Date**: 2026-03-13
**Previous**: [talk24.md](talk24.md) — Backstage (RHDH) Deployment
**Plan**: PLAN-004-backstage-api-entities.md

**What changed**:
- Added SCRIPT_PROVIDES_APIS and SCRIPT_CONSUMES_APIS fields to service definitions
- Updated catalog generator to produce kind: API entities with text descriptions
- 7 API entities generated: litellm-api, openwebui-api, openmetadata-api,
  authentik-api, gravitee-api, grafana-api, tika-api

---

## Contributor Message 1

Hi tester! We've added API entities to the Backstage catalog.

### Step 1: Restart with updated container

UIS_IMAGE=uis-provision-host:local ./uis restart

Expected: Container restarts successfully.

### Step 2: Regenerate the catalog

UIS_IMAGE=uis-provision-host:local ./uis catalog generate

Expected: Output should include an APIs section showing 7 API entities.

### Step 3: Redeploy backstage

UIS_IMAGE=uis-provision-host:local ./uis undeploy backstage
UIS_IMAGE=uis-provision-host:local ./uis deploy backstage

### Step 4: Check API entities in the browser

Open http://backstage.localhost

Test A — Go to APIs page, verify 7 API entities listed
Test B — Go to litellm component, check APIs tab shows "litellm-api" under Provided APIs
Test C — Go to openwebui component, check it shows "litellm-api" under Consumed APIs
Test D — Click litellm-api, verify detail page shows description, type, system, owner
Test E — Go to tika component, verify "tika-api" under Provided APIs

---

## UIS-USER1 - Message 2

### Results

| Test | Result | Details |
|------|--------|---------|
| A | PASS | /api-docs page shows all 7 APIs |
| B | PASS | litellm-api under Provided APIs |
| C | PASS | openwebui-api provided, litellm-api consumed |
| D | PASS (with note) | Detail page correct, but Definition tab shows rendering error |
| E | PASS | tika-api under Provided APIs |

**Notes:**
1. URL correction: The correct URL is /api-docs not /apis
2. Definition tab rendering issue: The OpenAPI renderer shows "Unable to render
   this definition" because spec.type is openapi but the definition is plain text,
   not a valid OpenAPI spec.

---

## UIS-USER1 - Message 3

### Suggestion: Fix Definition tab

Three options:
1. Quick fix — change type to "description" (removes renderer error)
2. Point to in-cluster OpenAPI endpoint via $text reference (runtime fetch)
3. Store static spec copies in repo (goes stale)

Recommendation: Option 1 now, Option 2 as future enhancement.

---

## Contributor Message 4

Applied Option 1 — changed spec.type from openapi to description. Container rebuilt.

### Verify:
1. Restart, regenerate, redeploy
2. Go to litellm-api Definition tab
3. Expected: No rendering error, text description displays cleanly

---

## UIS-USER1 - Message 5

**Result:** PASS — Type badge now shows "description", Definition tab displays
cleanly with no error. Text shows "Unified API gateway for LLM providers".

---

## UIS-USER1 - Message 6

### Suggestion: Add Kubernetes annotations to API entities

The K8s tab on API entities shows "Missing Annotation". Component entities have
kubernetes-label-selector and kubernetes-namespace annotations but API entities
don't. Request: inherit K8s annotations from the parent component.

---

## Contributor Message 7

Done — API entities now inherit K8s annotations from their parent service.
Container rebuilt. Please verify the K8s tab on litellm-api and tika-api.

---

## UIS-USER1 - Message 8

| API Entity | K8s Tab | Result |
|------------|---------|--------|
| litellm-api | "No Kubernetes resources" (not deployed) | PASS |
| tika-api | "No Kubernetes resources" (not deployed) | PASS |

No more "Missing Annotation" errors. Annotations present, plugin queries cluster
correctly.
```

</details>

Notice how the session uncovered three real issues:
1. **Wrong URL** in the test instructions (`/apis` vs `/api-docs`)
2. **Rendering error** on the Definition tab (wrong `spec.type` for text definitions)
3. **Missing K8s annotations** on API entities (tester suggestion led to a feature addition)

None of these would have been caught by automated tests.
