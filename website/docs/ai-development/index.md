---
title: Developing with AI
sidebar_position: 1
---

# Developing with AI

This project uses AI-assisted development with Claude Code to implement features, fix bugs, and maintain the infrastructure codebase.

**How it works:** Three things make AI development effective: containment, plans, and validation.

---

## 1. Containment: Keep AI Focused

AI coding assistants can read files, write code, and run commands. You want them focused on your project.

**The workspace is the boundary.**

```
┌─────────────────────────────────────────────────┐
│  Your Machine                                   │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  /workspace (your repo)                   │  │
│  │  - AI can only see this folder            │  │
│  │  - All changes are visible to you         │  │
│  │  - Git tracks every change                │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ~/Documents, ~/.ssh, ~/other-projects          │
│  (AI should not access these)                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

The AI operates within your repository. If something goes wrong, git reset and start fresh.

---

## 2. The Plan: Stop AI from Hallucinating

Without guidance, AI assistants:
- Jump straight into coding without understanding the scope
- Invent file locations that don't exist
- Create code that doesn't match your patterns
- Forget steps mid-implementation

**Make the AI create a plan first.**

Instead of "implement feature X", say:

```
we need to create a plan for adding a new Kubernetes manifest
```

The AI reads your documentation and creates a structured plan:

1. AI reads your plan templates and conventions
2. AI creates a phased plan with specific tasks
3. **You review before any code is written**

The plan is a markdown file. Edit it if something's wrong. Only after you approve does the AI start coding.

:::tip Why Plans Work
**They reduce hallucinations.** The AI follows your documented patterns instead of guessing.

**They enable course correction.** When something goes wrong, point to the plan. There's a shared reference.

**They create documentation.** Completed plans show what was implemented and why.
:::

Learn more: [Creating Plans](./creating-plans.md)

---

## 3. Validation: Verify the Work

Plans reduce errors but don't eliminate them. Validation catches what plans miss.

For infrastructure work, validation includes:
- Manifest syntax validation (`kubectl apply --dry-run=client`)
- Deployment verification (`kubectl rollout status`)
- Service connectivity tests
- Documentation review

When validation exists:
1. The AI runs checks after changes
2. Failures tell the AI exactly what's wrong
3. The AI fixes issues before you even see them

---

## The Three Layers

| Layer | What it does |
|-------|--------------|
| **Containment** | Limits AI to your repo - protects your machine |
| **Plans** | Guides AI behavior - reduces hallucinations |
| **Validation** | Verifies AI output - catches mistakes automatically |

1. **Contain it** - Workspace limits what the AI can access
2. **Guide it** - Plans keep the AI on track
3. **Verify it** - Validation catches errors before you do

---

## Getting Started

### 1. Install Claude Code

Follow the [Claude Code installation guide](https://docs.anthropic.com/en/docs/claude-code).

### 2. Configure API Key

Set your Anthropic API key:
```bash
export ANTHROPIC_API_KEY=your-api-key
```

### 3. Start Using It

```bash
claude
```

Then tell it what you want to build. It will create a plan for your review.

---

## Next Steps

- [Workflow](./workflow.md) - The full flow from idea to implementation
- [Creating Plans](./creating-plans.md) - Plan templates and best practices
