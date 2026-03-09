---
description: "Sequential agent workflow for complex tasks"
targets: ["claudecode"]
---

# Orchestrate Command

## Purpose

Chain multiple specialized agents in a structured workflow for complex tasks
that require planning, implementation, review, and verification. Ensures
consistent quality by passing handoff documents between agents.

## When to Use

- Implementing a complete feature end-to-end
- Fixing a complex bug that spans multiple files
- Performing a large-scale refactoring
- Any task that benefits from multiple specialized perspectives

## Arguments

- `--type=feature` — Full feature workflow (default)
- `--type=bugfix` — Bug diagnosis and fix workflow
- `--type=refactor` — Safe refactoring workflow
- `--type=security` — Security audit and remediation workflow

## Workflow Types

### Feature Workflow

```
planner → tdd-guide → code-reviewer → security-reviewer → verify
```

1. **Planner**: Restate requirements, assess risks, create phased plan
2. **TDD Guide**: For each phase, scaffold → test → implement → refactor
3. **Code Reviewer**: Review all changes for quality and patterns
4. **Security Reviewer**: Check for vulnerabilities (parallel with code review)
5. **Verify**: Run build → lint → tests → coverage

### Bugfix Workflow

```
planner (diagnose) → tdd-guide (reproduce + fix) → code-reviewer → verify
```

1. **Planner**: Analyze bug report, identify root cause, plan fix
2. **TDD Guide**: Write test reproducing the bug, then fix it
3. **Code Reviewer**: Review the fix for correctness and side effects
4. **Verify**: Run full test suite to check for regressions

### Refactor Workflow

```
planner (scope) → refactor-cleaner → code-reviewer → verify
```

1. **Planner**: Define refactoring scope and safety boundaries
2. **Refactor Cleaner**: Execute refactoring with test verification at each step
3. **Code Reviewer**: Verify refactoring preserved behavior
4. **Verify**: Full verification pipeline

### Security Workflow

```
security-reviewer → planner (remediation) → tdd-guide (fixes) → verify
```

1. **Security Reviewer**: Full security audit of target code
2. **Planner**: Create remediation plan for findings
3. **TDD Guide**: Implement fixes with tests proving vulnerability is closed
4. **Verify**: Full verification including security re-scan

## Handoff Documents

Between each agent, a handoff document is created:

```
## Handoff: <from-agent> → <to-agent>

### Context
<what was done in the previous stage>

### Artifacts
<files created or modified>

### Key Decisions
<important choices made and why>

### Open Questions
<unresolved items for the next agent>

### Constraints
<rules the next agent must follow>
```

## Parallel Opportunities

Within the orchestration, some steps can run in parallel:

- Code review + Security review (independent analyses)
- Test generation for independent modules
- Documentation updates alongside verification

## Output Format

```
## Orchestration Report — Type: <type>

### Pipeline
| Stage | Agent | Status | Duration |
|-------|-------|--------|----------|
| 1 | planner | DONE | — |
| 2 | tdd-guide | DONE | — |
| 3 | code-reviewer | DONE | — |
| 4 | security-reviewer | DONE | — |
| 5 | verify | PASS | — |

### Summary
- Files created: <count>
- Files modified: <count>
- Tests added: <count>
- Issues found and fixed: <count>
- Final coverage: <percent>%
```

## Rules

- Each agent receives the full handoff document from the previous stage
- If any stage fails, stop and report (do not skip stages)
- User confirmation is required after the planning stage
- Security findings of CRITICAL severity halt the pipeline
- All changes must pass verification before the workflow is complete
