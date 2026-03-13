# Developer Documentation

This folder contains documentation for AI coding assistants and developers working on urbalurba-infrastructure.

## Contents

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Instructions for Claude Code when working on this project |

## AI Development Workflow

For detailed AI development documentation, see:

- [AI Developer Guide](../website/docs/ai-developer/README.md) - Overview for AI coding assistants
- [Workflow](../website/docs/ai-developer/WORKFLOW.md) - The full flow from idea to implementation
- [Plans](../website/docs/ai-developer/PLANS.md) - Plan structure, templates, and best practices

### Plans Location

Implementation plans are stored in:

```
website/docs/ai-developer/plans/
├── active/      # Currently being worked on
├── backlog/     # Approved plans waiting for implementation
└── completed/   # Done - kept for reference
```

## Published Documentation

The public documentation site is built from `website/docs/` and published to [uis.sovereignsky.no](https://uis.sovereignsky.no).

To run the documentation site locally:

```bash
cd website
npm install
npm run start
```

## Related Files

- `/CLAUDE.md` - Main project instructions (repo root)
- `/website/docs/` - Docusaurus documentation source
