---
description: "Safely identify and remove dead code with test verification at every step"
targets: ["claudecode"]
---

# Refactor Clean Command

## Purpose

Identify and safely remove dead code, unused imports, unreachable branches,
and deprecated patterns. Every deletion is verified by running the test suite
to ensure nothing breaks.

## When to Use

- During scheduled code maintenance
- When file sizes grow beyond 800 lines
- After removing a feature or deprecating an API
- When static analysis reports unused code
- Before a major refactoring effort (clean first)

## Workflow

### Step 1: Static Analysis Scan

Run available analysis tools:

- **detekt** — Unused imports, dead code, complexity metrics
- **SpotBugs** — Unreachable code, redundant null checks
- **Gradle** — Unused dependencies via dependency analysis plugin
- **IDE inspections** — If available via MCP tools
- **Manual scan** — Unused private methods, unreferenced classes

### Step 2: Categorize Findings

| Safety Level | Category                | Examples                                                     |
|--------------|-------------------------|--------------------------------------------------------------|
| SAFE         | Unused imports          | Import statements with no references                         |
| SAFE         | Unused private members  | Private methods/fields never called                          |
| MODERATE     | Unused internal members | Internal functions with no callers in module                 |
| MODERATE     | Dead branches           | else-if or when branches that can never match                |
| RISKY        | Unused public API       | Public methods with no callers (may have external consumers) |
| RISKY        | Deprecated code         | @Deprecated methods still referenced elsewhere               |

### Step 3: Atomic Deletion Cycle

For each finding (starting with SAFE, then MODERATE):

1. Remove the dead code
2. Run `./gradlew test` (or equivalent)
3. If tests PASS: keep the deletion, record it
4. If tests FAIL: revert the deletion, flag as false positive
5. Move to next finding

### Step 4: Handle RISKY Findings

- Present RISKY findings to the user for confirmation
- Check git history for recent usage (last 90 days)
- Search for references in configuration files, scripts, documentation
- Only delete with explicit user approval

### Step 5: Report Results

Summarize all changes made and their impact.

## Output Format

```
## Refactor Clean Report

### Scan Results
- Total findings: <count>
- SAFE: <count> | MODERATE: <count> | RISKY: <count>

### Deletions Made
| File | Type | Description | Lines Saved |
|------|------|-------------|-------------|
| UserService.kt | Unused import | java.util.Date | 1 |
| OrderMapper.kt | Dead method | mapLegacyOrder() | 23 |

### Skipped (RISKY — needs confirmation)
- [UserController.kt] deprecatedEndpoint() — last used 120 days ago
- [Utils.kt] formatPhoneNumber() — public, no internal callers

### Summary
- Files modified: <count>
- Lines removed: <count>
- Tests: ALL PASSING
```

## Rules

- NEVER delete code without running tests after each deletion
- NEVER delete RISKY code without user confirmation
- Revert immediately if tests fail
- Keep deletions atomic (one logical change at a time)
- Do not refactor structure in this command (use dedicated refactoring for that)
- Commit after all safe deletions are verified

## Agent

This command invokes the **refactor-cleaner** agent for dead code identification.
