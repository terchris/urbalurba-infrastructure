---
title: Plans
sidebar_position: 3
---

# Implementation Plans

How we plan, track, and implement features and fixes.

**Related:** [WORKFLOW.md](WORKFLOW.md) - End-to-end flow from idea to implementation

---

## Folder Structure

```
website/docs/ai-development/ai-developer/plans/
├── backlog/      # Approved plans waiting for implementation
├── active/       # Currently being worked on (max 1-2 at a time)
└── completed/    # Done - kept for reference
```

### Flow

```
Idea/Problem → PLAN file in backlog/ → active/ → completed/
                       ↓
              (or INVESTIGATE file first if unclear)
```

---

## File Types

### PLAN-*.md

For work that is **ready to implement**. The scope is clear, the approach is known.

**When to create:**
- Bug fix with known solution
- Feature request with clear requirements
- Infrastructure change with defined scope

**Naming Conventions:**

| Format | Use Case | Example |
|--------|----------|---------|
| `PLAN-<short-name>.md` | Standalone plan, no specific order | `PLAN-postgres-backup-cronjob.md` |
| `PLAN-<nnn>-<short-name>.md` | Ordered sequence, indicates execution order | `PLAN-001-monitoring-foundation.md` |

#### Ordered Plans (PLAN-nnn-*)

When an investigation produces multiple related plans that should be executed in a specific order, use **three-digit numbering** to indicate the sequence:

```
PLAN-001-monitoring-foundation.md      # Must be done first (critical foundation)
PLAN-002-prometheus-config.md          # Can start after 001
PLAN-003-grafana-dashboards.md         # Depends on 002
PLAN-004-alerting-rules.md             # Depends on 003
```

**Benefits of ordered numbering:**
- Clear execution sequence at a glance
- Dependencies are implicit in the number order
- Easy to track progress through a large initiative
- Files sort naturally in file explorers

**When to use ordered numbering:**
- Investigation produces 3+ related plans
- Plans have sequential dependencies
- Work is part of a larger initiative (e.g., monitoring stack overhaul)

**When NOT to use ordered numbering:**
- Standalone bug fix or small feature
- Plans can be executed in any order
- Single plan from an investigation

### INVESTIGATE-*.md

For work that **needs research first**. The problem exists but the solution is unclear.

**When to create:**
- Complex infrastructure where options need evaluation
- Bug with unknown root cause
- Feature requiring architectural decisions

**Naming:** `INVESTIGATE-<topic>.md`

Examples:
- `INVESTIGATE-monitoring-architecture.md`
- `INVESTIGATE-multi-cluster-networking.md`

**After investigation:** Create one or more PLAN files with the chosen approach.

---

## Plan Structure

Every plan has these sections:

### 1. Header (Required)

```markdown
# Plan Title

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog | Active | Blocked | Completed

**Goal**: One sentence describing what this achieves.

**Last Updated**: 2026-01-18

**GitHub Issue**: #42 (optional - if tracking with issues)
```

The **IMPLEMENTATION RULES** blockquote ensures Claude Code reads the workflow and plan guidelines before starting work.

### 2. Dependencies (If applicable)

```markdown
**Prerequisites**: PLAN-001 must be complete first
**Blocks**: PLAN-003 cannot start until this is done
**Priority**: High | Medium | Low
```

For ordered plans (PLAN-nnn-*), dependencies are often implicit in the number order. Only add explicit dependency notes when the relationship is non-obvious.

### 3. Problem Summary (Required)

What's wrong or what's needed. Be specific.

### 4. Phases with Tasks (Required)

Break work into phases. Each phase has:
- Numbered tasks
- A validation step at the end (usually user confirmation)

```markdown
## Phase 1: Setup

### Tasks

- [ ] 1.1 Create the ConfigMap
- [ ] 1.2 Add validation rules
- [ ] 1.3 Test with dry-run

### Validation

User confirms phase is complete.

---

## Phase 2: Implementation

### Tasks

- [ ] 2.1 Create the deployment manifest
- [ ] 2.2 Add the service manifest
- [ ] 2.3 Apply and verify deployment

### Validation

User confirms deployment works correctly.
```

### 5. Acceptance Criteria (Required)

```markdown
## Acceptance Criteria

- [ ] Manifests apply without errors
- [ ] Pods are running and healthy
- [ ] Service is accessible
- [ ] Documentation is updated
```

### 6. Implementation Notes (Optional)

Technical details, gotchas, code patterns to follow.

### 7. Files to Modify (Optional but helpful)

```markdown
## Files to Modify

- `manifests/250-new-service.yaml`
- `docs/packages/new-service.md`
```

---

## Status Values

| Status | Meaning | Location |
|--------|---------|----------|
| `Backlog` | Approved, waiting to start | `backlog/` |
| `Active` | Currently being worked on | `active/` |
| `Blocked` | Waiting on something else | `backlog/` or `active/` |
| `Completed` | Done | `completed/` |

---

## Updating Plans During Implementation

**Critical:** Plans are living documents. Update them as you work.

### When starting a phase:

```markdown
## Phase 2: Implementation — IN PROGRESS
```

### When completing a task:

```markdown
- [x] 2.1 Update the manifest ✓
- [ ] 2.2 Add the service
```

### When a phase is done:

```markdown
## Phase 2: Implementation — ✅ DONE
```

### When blocked:

```markdown
## Status: Blocked

**Blocked by**: Waiting for decision on approach
```

### When complete:

1. Update status: `## Status: Completed`
2. Add completion date: `**Completed**: 2026-01-18`
3. Move file: `mv website/docs/ai-development/ai-developer/plans/active/PLAN-xyz.md website/docs/ai-development/ai-developer/plans/completed/`
4. (Optional) Close GitHub issue if using issue tracking

---

## Validation

Every phase ends with validation. The simplest form is asking the user to confirm.

### Default: User Confirmation

Claude asks: "Phase 1 complete. Does this look good to continue?"

In the plan, this can be written as:

```markdown
### Validation

User confirms phase is complete.
```

### Optional: Automated Check

When a command can verify the work, include it:

```markdown
### Validation

```bash
kubectl apply --dry-run=client -f manifests/xxx-new-service.yaml
kubectl get pods -n namespace -l app=new-service
```

User confirms output is correct.
```

### Key Point

Don't force automated validation when it's impractical. User confirmation is valid and often the best approach.

---

## Plan Templates

### Simple Bug Fix

```markdown
# Fix: [Bug Description]

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: [One sentence]

**GitHub Issue**: #XX (optional)

**Last Updated**: YYYY-MM-DD

---

## Problem

[What's broken]

## Solution

[How to fix it]

---

## Phase 1: Fix

### Tasks

- [ ] 1.1 [Specific change]
- [ ] 1.2 [Another change]

### Validation

User confirms fix is correct.

---

## Acceptance Criteria

- [ ] Bug is fixed
- [ ] No regressions
- [ ] Manifests apply cleanly
```

### Feature Implementation

```markdown
# Feature: [Feature Name]

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: [One sentence]

**GitHub Issue**: #XX (optional)

**Last Updated**: YYYY-MM-DD

---

## Overview

[What this feature does and why]

---

## Phase 1: [Setup/Preparation]

### Tasks

- [ ] 1.1 [Task]
- [ ] 1.2 [Task]

### Validation

User confirms phase is complete.

---

## Phase 2: [Core Implementation]

### Tasks

- [ ] 2.1 [Task]
- [ ] 2.2 [Task]

### Validation

User confirms phase is complete.

---

## Acceptance Criteria

- [ ] [Criterion]
- [ ] Deployment succeeds
- [ ] Services are accessible
- [ ] Documentation updated

---

## Files to Modify

- `manifests/xxx-new-feature.yaml`
```

### Investigation

```markdown
# Investigate: [Topic]

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine the best approach for [topic]

**Last Updated**: YYYY-MM-DD

---

## Questions to Answer

1. [Question 1]
2. [Question 2]

---

## Current State

[What exists now]

---

## Options

### Option A: [Name]

**Pros:**
-

**Cons:**
-

### Option B: [Name]

**Pros:**
-

**Cons:**
-

---

## Recommendation

[After investigation, what do we do?]

---

## Next Steps

- [ ] Create PLAN-xyz.md with chosen approach
  - For multiple related plans, use ordered naming: PLAN-001-*, PLAN-002-*, etc.
```

---

## Working with Claude Code

See [WORKFLOW.md](WORKFLOW.md) for the complete flow from idea to implementation.

---

## Best Practices

1. **One active plan at a time** - finish before starting another
2. **Small phases** - easier to validate and recover from errors
3. **Specific tasks** - "Update line 42 in manifests/xyz.yaml" not "Fix the thing"
4. **Runnable validation** - commands, not descriptions
5. **Update as you go** - the plan is the source of truth
6. **Keep completed plans** - they're documentation
