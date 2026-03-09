---
description: "Create or verify a checkpoint in your workflow"
targets: ["claudecode"]
---

# Checkpoint Command

## Purpose

Create named save points during complex workflows so you can track progress,
verify intermediate state, and roll back if needed. Checkpoints use git
stash or lightweight commits to preserve state without polluting history.

## When to Use

- Before risky changes during a refactoring
- After completing a phase in a multi-phase plan
- When you want to save progress before experimenting
- To verify that intermediate state is correct before proceeding
- As a safety net during `/orchestrate` workflows

## Arguments

- `create <name>` — Create a new checkpoint with the given name
- `verify <name>` — Verify that a checkpoint exists and is valid
- `list` — List all checkpoints in the current session
- `restore <name>` — Restore state from a checkpoint (requires confirmation)
- No arguments — Show checkpoint status and recent checkpoints

## Workflow

### Creating a Checkpoint

1. Capture current state:
    - Run `git stash create` to create a stash object without modifying working tree
    - Or create a lightweight commit on a temporary branch
2. Record metadata:
    - Checkpoint name
    - Timestamp
    - Current branch
    - Files modified since last checkpoint
    - Brief description of what was accomplished
3. Log entry to `.claude/checkpoints.log`

### Verifying a Checkpoint

1. Confirm the checkpoint reference exists in git
2. Show what has changed since that checkpoint:
    - Files modified
    - Lines added/removed
    - Tests passing/failing
3. Report whether current state is healthy

### Listing Checkpoints

Display all checkpoints from the current session:

```
## Checkpoints

| # | Name | Time | Branch | Files Changed |
|---|------|------|--------|---------------|
| 1 | phase-1-complete | 10:32 | feature/users | 5 |
| 2 | pre-refactor | 11:15 | feature/users | 5 |
| 3 | tests-passing | 11:48 | feature/users | 8 |
```

### Restoring a Checkpoint

1. Show diff between current state and checkpoint
2. Ask for explicit user confirmation
3. Restore files to checkpoint state
4. Verify build and tests pass after restore
5. Log the restoration

## Log Format

Entries in `.claude/checkpoints.log`:

```
[2024-01-15T10:32:00Z] CREATE phase-1-complete branch=feature/users files=5 ref=abc1234
[2024-01-15T11:15:00Z] CREATE pre-refactor branch=feature/users files=5 ref=def5678
[2024-01-15T11:48:00Z] CREATE tests-passing branch=feature/users files=8 ref=ghi9012
[2024-01-15T12:30:00Z] RESTORE pre-refactor branch=feature/users ref=def5678
```

## Output Format

```
## Checkpoint Created: <name>

- Branch: <branch>
- Ref: <short-hash>
- Files tracked: <count>
- Since last checkpoint: +<added> / -<removed> lines
- Tests: PASSING / FAILING
- Build: OK / BROKEN

Checkpoint saved. Use `/checkpoint verify <name>` to check status.
```

## Rules

- NEVER auto-restore without explicit user confirmation
- ALWAYS verify build state when creating a checkpoint
- Keep checkpoint names short and descriptive (kebab-case)
- Checkpoints are session-scoped — they do not persist across sessions
- Do not create checkpoints for trivial changes
- Warn if more than 10 checkpoints exist (suggests overly cautious workflow)
