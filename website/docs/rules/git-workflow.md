# Git Workflow Rules

**File**: `docs/rules-git-workflow.md`
**Purpose**: Standardized Git workflow and branching strategy for urbalurba-infrastructure
**Target Audience**: All contributors to the repository
**Last Updated**: September 21, 2024

## 📋 **Overview**

This document establishes Git workflow rules to ensure consistent, professional development practices and maintain code quality through proper branching, review, and merge strategies.

## 🎯 **Core Principles**

### **Principle 1: Feature Branch Workflow**
- All development work happens on feature branches
- Never commit directly to `main` branch
- Feature branches are short-lived and focused on single features/fixes

### **Principle 2: Pull Request Required**
- All changes to `main` must go through Pull Requests (PRs)
- PRs enable code review, discussion, and quality control
- PRs provide permanent documentation of changes and reasoning

### **Principle 3: Clean History**
- Commit messages should be clear and descriptive
- Feature branches should be deleted after merge
- Main branch should have a clean, linear history

## 🚀 **Mandatory Workflow Steps**

### **Step 1: Create Feature Branch**
```bash
# Always start from latest main
git checkout main
git pull origin main

# Create descriptive feature branch
git checkout -b feature/descriptive-name
```

**Branch Naming Convention:**
- `feature/` + descriptive name using kebab-case
- Examples: `feature/litellm-shared-postgres`, `feature/git-workflow-rules`
- Be specific: `feature/fix-tika-readiness` not `feature/fix-bug`

### **Step 2: Development and Commits**
```bash
# Make your changes
# Commit frequently with clear messages
git add .
git commit -m "Clear description of what changed and why"
```

**Commit Message Rules:**
- Start with action verb (add, fix, update, remove, refactor)
- Be specific about what changed
- Include context if needed
- Examples:
  - ✅ `Fix LiteLLM pod readiness check to wait for Ready condition`
  - ✅ `Add 30-second initialization pause for OpenWebUI service test`
  - ❌ `bug fix`
  - ❌ `updates`

### **Step 3: Push and Create Pull Request**
```bash
# Push feature branch to remote
git push origin feature/your-branch-name

# Create PR using GitHub CLI (preferred)
gh pr create --title "Descriptive PR Title" --body "$(cat <<'EOF'
## Summary
- Bullet point of key changes
- What problem this solves
- Impact on existing functionality

## Technical Changes
- Specific files/components modified
- New patterns or approaches introduced
- Breaking changes (if any)

## Test Results
- How you verified the changes work
- Specific test scenarios covered
- Performance impact (if applicable)

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**PR Title Format:**
- Start with action verb
- Be specific and descriptive
- Examples:
  - ✅ `Fix LiteLLM deployment with shared PostgreSQL and enhanced reliability`
  - ✅ `Add Git workflow rules documentation`
  - ❌ `Updates`
  - ❌ `Bug fixes`

### **Step 4: Code Review and Merge**
```bash
# Open PR in browser for review
gh pr view --web

# After review/approval, merge via GitHub web interface
# Choose "Squash and merge" for clean history
```

### **Step 5: Clean Up**
```bash
# Switch back to main and pull merged changes
git checkout main
git pull origin main

# Delete local feature branch
git branch -d feature/your-branch-name
```

## ✅ **Required PR Content**

### **PR Description Template**
Every PR must include:

```markdown
## Summary
- [Bullet point describing main change]
- [Problem this solves]
- [Impact on users/system]

## Technical Changes
- [Specific files modified]
- [New patterns introduced]
- [Dependencies added/removed]

## Test Results
- [How changes were verified]
- [Test scenarios covered]
- [Performance impact]

## Breaking Changes
- [List any breaking changes]
- [Migration steps required]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### **Required PR Checks**
Before creating PR, verify:
- [ ] All changes committed and pushed
- [ ] PR title follows naming convention
- [ ] PR description is complete and detailed
- [ ] Changes have been tested
- [ ] No secrets or sensitive data included
- [ ] Code follows existing patterns and conventions

## 🚫 **Prohibited Practices**

### **❌ Never Do This:**
- Direct commits to `main` branch
- Force push to shared branches
- Commit secrets, API keys, or sensitive data
- Create PR without description
- Leave stale feature branches
- Merge without review (except for solo documentation updates)

### **❌ Avoid These Patterns:**
- Generic commit messages ("fix", "update", "changes")
- Large PRs that change multiple unrelated things
- Keeping feature branches alive after merge
- Working on main branch directly

## 🔧 **Tools and Setup**

### **Required Tools**
```bash
# Install GitHub CLI for PR management
brew install gh

# Authenticate with GitHub
gh auth login
```

### **Recommended Git Configuration**
```bash
# Set up helpful aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status

# Set up default branch behavior
git config --global pull.rebase false
git config --global init.defaultBranch main
```

## 📊 **Workflow Examples**

### **Example 1: Adding New Feature**
```bash
# 1. Start from main
git checkout main && git pull origin main

# 2. Create feature branch
git checkout -b feature/authentik-oauth-integration

# 3. Make changes and commit
git add . && git commit -m "Add Authentik OAuth integration for OpenWebUI"

# 4. Push and create PR
git push origin feature/authentik-oauth-integration
gh pr create --title "Add Authentik OAuth integration for OpenWebUI" --body "..."

# 5. Merge via web interface, then cleanup
git checkout main && git pull origin main
git branch -d feature/authentik-oauth-integration
```

### **Example 2: Fixing Bug**
```bash
# 1. Start from main
git checkout main && git pull origin main

# 2. Create fix branch
git checkout -b feature/fix-tika-service-connectivity

# 3. Make fix and commit
git add . && git commit -m "Fix Tika service connectivity timeout issues"

# 4. Create PR with detailed description
gh pr create --title "Fix Tika service connectivity timeout issues" --body "..."

# 5. Merge and cleanup
git checkout main && git pull origin main
git branch -d feature/fix-tika-service-connectivity
```

## 🎯 **PR Review Standards**

### **Review Criteria**
When reviewing PRs, check for:
- [ ] Clear problem statement and solution in PR description
- [ ] Descriptive PR title following naming convention
- [ ] Complete PR description using required template
- [ ] Appropriate branch naming (feature/descriptive-name)
- [ ] Clean commit messages following standards
- [ ] No sensitive data (secrets, API keys) included
- [ ] Documentation updated for user-facing changes

## 🚨 **Emergency Procedures**

### **Hotfix Process**
For critical production issues:
1. Create `hotfix/issue-description` branch from main
2. Make minimal fix with detailed commit message
3. Create PR with `[HOTFIX]` prefix in title
4. Fast-track review and merge
5. Follow up with proper investigation in separate feature branch

### **Rollback Process**
If merged change causes issues:
1. Create `feature/revert-problematic-change` branch
2. Use `git revert` to create rollback commit
3. Create PR explaining rollback reasoning
4. Merge immediately if critical
5. Create follow-up feature branch to address root cause

## 📚 **Learning Resources**

### **Git Best Practices**
- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Writing Good Commit Messages](https://chris.beams.io/posts/git-commit/)
- [Pull Request Best Practices](https://github.com/blog/1943-how-to-write-the-perfect-pull-request)

### **Internal Documentation**
- `docs/rules-provisioning.md` - Deployment and infrastructure rules
- `docs/rules-ingress-traefik.md` - Networking and ingress rules

## 📝 **Summary**

### **Golden Rules**
1. **Always use feature branches** - never work directly on main
2. **Always create Pull Requests** - enable review and documentation
3. **Write descriptive commit messages** - explain what and why
4. **Test your changes** - verify functionality before PR
5. **Clean up after merge** - delete feature branches
6. **Document significant changes** - update relevant documentation

### **Benefits of This Workflow**
- ✅ **Quality Control** - Code review prevents bugs and maintains standards
- ✅ **Documentation** - PR descriptions provide change history and context
- ✅ **Collaboration** - Team members can discuss and improve changes
- ✅ **Safety** - Feature branches protect main from experimental code
- ✅ **Traceability** - Clear audit trail of who changed what and why

This workflow ensures professional development practices while maintaining the agility needed for infrastructure experimentation and rapid iteration.