---
title: AI Developer Guide
sidebar_position: 1
---

# AI Developer Documentation

Instructions for AI coding assistants (Claude, Copilot, etc.) working on urbalurba-infrastructure.

---

## Documents

| Document | Purpose |
|----------|---------|
| [WORKFLOW.md](WORKFLOW.md) | End-to-end flow from idea to implemented feature (start here) |
| [PLANS.md](PLANS.md) | Plan structure, templates, and how to write plans |

---

## Plans Folder

Implementation plans are stored in `plans/`:

```
plans/
├── active/      # Currently being worked on (max 1-2 at a time)
├── backlog/     # Approved plans waiting for implementation
└── completed/   # Done - kept for reference
```

### File Types

| Type | When to use |
|------|-------------|
| `PLAN-*.md` | Solution is clear, ready to implement |
| `INVESTIGATE-*.md` | Needs research first, approach unclear |

---

## Quick Reference

### When user says "I want to add X" or "Fix Y":

1. Create `PLAN-*.md` in `plans/backlog/`
2. Ask user to review the plan
3. Wait for approval before implementing

### When user approves a plan:

1. Ask: "Do you want to work on a feature branch? (recommended)"
2. Create branch if yes
3. Move plan to `plans/active/`
4. Implement phase by phase
5. Ask user to confirm after each phase

### When implementation is complete:

1. Move plan to `plans/completed/`
2. Create Pull Request if on feature branch

### When creating new manifests or services:

1. Follow the manifest numbering conventions (see `manifests/` folder)
2. Use appropriate namespace for the service category
3. **Validate before committing**: `kubectl apply --dry-run=client -f manifests/xxx-new-service.yaml`
4. Test deployment: `kubectl rollout status deployment/xxx -n namespace`

---

## Related Documentation

- [CLAUDE.md](https://github.com/terchris/urbalurba-infrastructure/blob/main/CLAUDE.md) - Project-specific Claude Code instructions (in repo root)
- [Packages documentation](../../packages/ai/index.md) - Service documentation
- [Hosts documentation](../../hosts/index.md) - Infrastructure host setup
