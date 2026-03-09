---
root: false
targets: ["claudecode"]
description: "Git workflow: conventional commits, PR process, branching"
globs: ["**/*"]
---

# Git Workflow

## Commit Message Format

```
<type>: <description>

<optional body>
```

**Types:**

- `feat` — new feature
- `fix` — bug fix
- `refactor` — code restructuring without behavior change
- `docs` — documentation only
- `test` — adding or updating tests
- `chore` — build, tooling, dependency updates
- `perf` — performance improvement
- `ci` — CI/CD configuration changes

**Rules:**

- Description in imperative mood ("add feature" not "added feature")
- Keep subject line under 72 characters
- Body explains WHY, not WHAT (the diff shows what)
- Reference issue/ticket numbers when applicable

## Pull Request Workflow

1. Analyze the full commit history, not just the latest commit
2. Use `git diff [base-branch]...HEAD` to see all changes included in the PR
3. Draft a comprehensive PR summary covering:
    - What changed and why
    - How to test the changes
    - Any breaking changes or migration steps
4. Include a test plan with concrete verification steps
5. Push new branches with the `-u` flag to set upstream tracking

## Branch Naming

- `feat/<description>` — feature branches
- `fix/<description>` — bug fix branches
- `refactor/<description>` — refactoring branches
- `chore/<description>` — maintenance branches

Keep branch names short, lowercase, hyphen-separated.
