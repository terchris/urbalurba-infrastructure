---
title: Creating Plans
sidebar_position: 3
---

# Creating Plans

How to structure plans for AI-assisted development.

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

**Naming:** `PLAN-<short-name>.md`

Examples:
- `PLAN-postgres-backup-cronjob.md`
- `PLAN-add-redis-cluster.md`

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

## Status: Backlog | Active | Blocked | Completed

**Goal**: One sentence describing what this achieves.

**Last Updated**: 2026-01-18
```

### 2. Problem Summary (Required)

What's wrong or what's needed. Be specific.

### 3. Phases with Tasks (Required)

Break work into phases. Each phase has:
- Numbered tasks
- A validation step at the end

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

### 4. Acceptance Criteria (Required)

```markdown
## Acceptance Criteria

- [ ] Manifests apply without errors
- [ ] Pods are running and healthy
- [ ] Service is accessible
- [ ] Documentation is updated
```

### 5. Files to Modify (Optional but helpful)

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

:::important
Plans are living documents. Update them as you work.
:::

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
3. Move file to `completed/`

---

## Plan Templates

### Simple Bug Fix

```markdown
# Fix: [Bug Description]

## Status: Backlog

**Goal**: [One sentence]

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

## Status: Backlog

**Goal**: [One sentence]

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
```

---

## Best Practices

1. **One active plan at a time** - finish before starting another
2. **Small phases** - easier to validate and recover from errors
3. **Specific tasks** - "Update line 42 in manifests/xyz.yaml" not "Fix the thing"
4. **Runnable validation** - commands, not descriptions
5. **Update as you go** - the plan is the source of truth
6. **Keep completed plans** - they're documentation
